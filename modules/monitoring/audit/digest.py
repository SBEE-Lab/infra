#!/usr/bin/env python3
"""Post a weekly audit digest to Slack #infra-audit through the alert bridge.

Queries rho-local Loki and Prometheus with the same expressions the Security &
audit dashboard uses. It posts even when everything is zero, so a missing
digest itself means the pipeline broke. Failed queries are reported in the
digest and make the run exit non-zero so ScheduledJobFailed fires.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.parse
import urllib.request
from collections.abc import Callable, Sequence
from datetime import datetime, timedelta, timezone
from pathlib import Path

LOKI = "http://127.0.0.1:3100"
PROMETHEUS = "http://127.0.0.1:9090"
GRAFANA = "https://logging.sjanglab.org"
KST = timezone(timedelta(hours=9))
SECTION_LIMIT = 2900


# Loki caps a query at 500 series, so extract only the fields a query groups by.
def public_404(field: str) -> str:
    return (
        f'{{log_type="nginx_access", ingress_network="public"}} | json {field}, status, user_agent'
        ' | status = "404" | user_agent !~ "Blackbox-Exporter.*"'
    )


# Scanners request thousands of distinct paths; bucket them by what they probe for.
PATH_CATEGORY = (
    '{{ if hasPrefix "/." .request_path }}dotfiles and VCS'
    '{{ else if or (contains "wp-" .request_path) (contains "xmlrpc" .request_path) }}WordPress'
    '{{ else if contains ".php" .request_path }}PHP files'
    '{{ else if or (contains "admin" .request_path) (contains "cgi-bin" .request_path)'
    ' (contains "actuator" .request_path) (contains "/api/" .request_path)'
    ' (contains "/vendor/" .request_path) }}admin, API, frameworks'
    "{{ else }}other{{ end }}"
)

Sample = tuple[dict[str, str], float]
Query = Callable[[str], list[Sample]]


def http_json(url: str) -> dict[str, object]:
    with urllib.request.urlopen(url, timeout=60) as response:
        return json.load(response)  # type: ignore[no-any-return]


def instant(base: str, path: str, expr: str) -> list[Sample]:
    payload = http_json(f"{base}{path}?" + urllib.parse.urlencode({"query": expr}))
    data = payload["data"]
    assert isinstance(data, dict)
    return [(row["metric"], float(row["value"][1])) for row in data["result"]]


def loki(expr: str) -> list[Sample]:
    return instant(LOKI, "/loki/api/v1/query", expr)


def prometheus(expr: str) -> list[Sample]:
    return instant(PROMETHEUS, "/api/v1/query", expr)


class Digest:
    def __init__(self, loki_query: Query, prom_query: Query) -> None:
        self.loki = loki_query
        self.prom = prom_query
        self.failures: list[str] = []

    def rows(self, name: str, query: Query, expr: str) -> list[Sample]:
        try:
            return sorted(query(expr), key=lambda row: -row[1])
        except Exception as error:  # noqa: BLE001 - every failure is reported in the digest
            self.failures.append(f"{name}: {error}")
            return []

    def total(self, name: str, query: Query, expr: str) -> str:
        before = len(self.failures)
        value = sum(value for _, value in self.rows(name, query, expr))
        return "?" if len(self.failures) > before else f"{value:,.0f}"

    def table(self, name: str, query: Query, expr: str, labels: Sequence[str], limit: int) -> str:
        rows = self.rows(name, query, expr)[:limit]
        if not rows:
            return "_none_"
        lines = [
            " · ".join(metric.get(label) or "-" for label in labels) + f" — {value:,.0f}"
            for metric, value in rows
        ]
        return "\n".join(f"• `{line}`" for line in lines)

    def sections(self) -> list[str]:
        week = "[7d]"
        indicators = (
            "*Intrusion indicators — every value should be 0*\n"
            f"Unclassified SSH logins: *{self.total('unclassified logins', self.loki, f'sum(count_over_time({{log_type="access_audit", event="ssh_login", path="unknown"}}{week}))')}*\n"
            f"New tailnet nodes: *{self.total('new nodes', self.loki, f'sum(count_over_time({{log_type="headscale_nodes", event="node_added"}}{week}))')}*\n"
            f"Sensitive paths served: *{self.total('sensitive paths', self.prom, 'sum(increase(nginx_public_sensitive_path_served_total[7d]))')}*\n"
            f"Exploit symptom alerts fired: *{self.total('exploit alerts', self.prom, 'count(max_over_time(ALERTS{alertname=~"ProcessCrashed|ProcessCrashLoop|PublicHttpServerErrorBurst", alertstate="firing"}[7d]))')}*"
        )
        new_nodes = "*New tailnet nodes*\n" + self.table(
            "new node list",
            self.loki,
            f'sum by (node, user, tags) (count_over_time({{log_type="headscale_nodes", event="node_added"}} | json node, user, tags{week}))',
            ("node", "user", "tags"),
            15,
        )
        logins = "*Successful SSH logins by origin*\n" + self.table(
            "login origins",
            self.loki,
            f'sum by (path, ssh_user, source_ip, key_fingerprint) (count_over_time({{log_type="access_audit", event="ssh_login"}} | json ssh_user, source_ip, key_fingerprint{week}))',
            ("path", "ssh_user", "source_ip", "key_fingerprint"),
            15,
        )
        pressure = (
            "*Attack pressure (trend only)*\n"
            f"fail2ban bans: {self.total('fail2ban bans', self.prom, 'sum(increase(f2b_jail_banned_total[7d]))')} · "
            f"SSH rejected before auth: {self.total('ssh scans', self.loki, f'sum(count_over_time({{log_type="ssh", event=~"invalid_user|preauth_rejected"}}{week}))')} · "
            f"forward-auth denials: {self.total('forward-auth', self.loki, f'sum(count_over_time({{log_type="authentik", event="forward_auth_deny"}}{week}))')}\n"
            "Top scanner sources:\n"
            + self.table(
                "scanner sources",
                self.loki,
                f"topk(5, sum by (source_ip) (count_over_time({public_404('source_ip')} | keep source_ip{week})))",
                ("source_ip",),
                5,
            )
            + "\n404s by what was probed:\n"
            + self.table(
                "scanner paths",
                self.loki,
                f"sum by (category) (count_over_time({public_404('request_path')}"
                f" | label_format category=`{PATH_CATEGORY}` | keep category{week}))",
                ("category",),
                5,
            )
        )
        links = f"<{GRAFANA}/d/sjanglab-access-audit|Security & audit> · <{GRAFANA}/d/sjanglab-edge|Public edge>"
        sections = [indicators, new_nodes, logins, pressure, links]
        if self.failures:
            sections.append(
                "*:warning: Queries failed — numbers above may be incomplete*\n"
                + "\n".join(f"• {f}" for f in self.failures)
            )
        return [truncate(section) for section in sections]


def truncate(text: str) -> str:
    return text if len(text) <= SECTION_LIMIT else text[: SECTION_LIMIT - 1] + "…"


def title(now: datetime) -> str:
    start = now - timedelta(days=7)
    return f"Weekly audit {start:%m/%d}–{now:%m/%d}"


def post(bridge_url: str, token: str, payload: dict[str, object]) -> None:
    request = urllib.request.Request(
        bridge_url,
        data=json.dumps(payload).encode(),
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=60) as response:
        body = json.load(response)
    if not body.get("ok"):
        raise RuntimeError(f"bridge rejected digest: {body}")


def run_self_tests() -> int:
    def fake_loki(expr: str) -> list[Sample]:
        if 'path="unknown"' in expr:
            return []
        if "ssh_user" in expr:
            return [
                (
                    {
                        "path": "bastion",
                        "ssh_user": "root",
                        "source_ip": "10.100.0.1",
                        "key_fingerprint": "SHA256:k",
                    },
                    28.0,
                )
            ]
        if "source_ip" in expr:
            raise OSError("loki down")
        return [({}, 3.0)]

    def fake_prom(expr: str) -> list[Sample]:
        return [({}, 0.0)] if "sensitive" in expr else []

    digest = Digest(fake_loki, fake_prom)
    sections = digest.sections()
    assert "Unclassified SSH logins: *0*" in sections[0], sections[0]
    assert "Sensitive paths served: *0*" in sections[0]
    assert "`bastion · root · 10.100.0.1 · SHA256:k — 28`" in sections[2], sections[2]
    assert "Queries failed" in sections[-1] and "scanner sources: loki down" in sections[-1]
    assert digest.failures == ["scanner sources: loki down"]
    assert all(len(section) <= SECTION_LIMIT for section in sections)
    assert len(truncate("x" * 5000)) == SECTION_LIMIT
    assert title(datetime(2026, 10, 23, 15, 30, tzinfo=KST)) == "Weekly audit 10/16–10/23"
    print("self-tests passed")
    return 0


def main(argv: Sequence[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bridge-url")
    parser.add_argument(
        "--dry-run", action="store_true", help="print the digest instead of posting"
    )
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args(argv)
    if args.self_test:
        return run_self_tests()

    digest = Digest(loki, prometheus)
    payload: dict[str, object] = {"title": title(datetime.now(KST)), "sections": digest.sections()}
    if args.dry_run:
        print(json.dumps(payload, indent=2, ensure_ascii=False))
    else:
        if not args.bridge_url:
            parser.error("--bridge-url is required unless --dry-run or --self-test")
        token = Path(os.environ["CREDENTIALS_DIRECTORY"], "bridge-token").read_text().strip()
        post(args.bridge_url, token, payload)
    if digest.failures:
        print(f"{len(digest.failures)} queries failed", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
