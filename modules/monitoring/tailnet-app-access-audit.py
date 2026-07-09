#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
import time
import urllib.parse
import urllib.request
from dataclasses import dataclass
from ipaddress import ip_address, ip_network
from pathlib import Path
from typing import NotRequired, Sequence, TypedDict, cast

JsonValue = None | bool | int | float | str | list["JsonValue"] | dict[str, "JsonValue"]
Event = dict[str, JsonValue]
TAILNET = ip_network("100.64.0.0/10")


class LokiValue(TypedDict):
    stream: dict[str, str]
    values: list[list[str]]


class LokiResponse(TypedDict):
    status: str
    data: dict[str, list[LokiValue]]


class PushStream(TypedDict):
    stream: dict[str, str]
    values: list[list[str]]


class State(TypedDict):
    seen: dict[str, float]


class CliArgs(TypedDict):
    loki_url: str
    state: Path
    nginx_window_seconds: int
    headscale_window_seconds: int
    seen_ttl_seconds: int
    query_limit: int
    dry_run: bool
    self_test: NotRequired[bool]


@dataclass(frozen=True)
class NodeMetadata:
    node: str
    user: str
    tags: list[str]
    online: bool | None
    health: str
    last_seen_seconds: int | None
    snapshot_timestamp_ns: int


def event_str(event: Event, key: str, default: str = "") -> str:
    value = event.get(key)
    if isinstance(value, str):
        return value
    if isinstance(value, (int, float)):
        return str(value)
    return default


def event_int(event: Event, key: str, default: int = 0) -> int:
    value = event.get(key)
    if isinstance(value, int):
        return value
    if isinstance(value, str):
        try:
            return int(value)
        except ValueError:
            return default
    return default


def event_bool(event: Event, key: str) -> bool | None:
    value = event.get(key)
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        normalized = value.lower()
        if normalized == "true":
            return True
        if normalized == "false":
            return False
    return None


def event_str_list(event: Event, key: str) -> list[str]:
    value = event.get(key)
    if isinstance(value, list):
        return [item for item in value if isinstance(item, str)]
    if isinstance(value, str) and value:
        return [item.strip() for item in value.split(",") if item.strip()]
    return []


def is_tailnet_ip(value: str) -> bool:
    try:
        return ip_address(value) in TAILNET
    except ValueError:
        return False


def is_tailnet_access(event: Event) -> bool:
    return event_str(event, "ingress_network") == "tailnet" or is_tailnet_ip(
        event_str(event, "source_ip")
    )


def status_class(status: str | int) -> str:
    try:
        code = int(status)
    except (TypeError, ValueError):
        return "unknown"
    if 200 <= code <= 299:
        return "2xx"
    if 300 <= code <= 399:
        return "3xx"
    if 400 <= code <= 499:
        return "4xx"
    if 500 <= code <= 599:
        return "5xx"
    return "unknown"


def parse_loki_events(payload: LokiResponse) -> list[Event]:
    events: list[Event] = []
    for result in payload["data"]["result"]:
        labels = result["stream"]
        for timestamp, line in result["values"]:
            try:
                event = cast(Event, json.loads(line))
            except json.JSONDecodeError:
                event = {"message": line}
            for key, value in labels.items():
                event.setdefault(key, value)
            event["_timestamp_ns"] = int(timestamp)
            events.append(event)
    events.sort(key=lambda item: event_int(item, "_timestamp_ns"))
    return events


def query_loki(loki_url: str, query: str, window_seconds: int, limit: int) -> list[Event]:
    end_ns = time.time_ns()
    start_ns = end_ns - window_seconds * 1_000_000_000
    params = urllib.parse.urlencode(
        {
            "query": query,
            "start": str(start_ns),
            "end": str(end_ns),
            "direction": "forward",
            "limit": str(limit),
        }
    )
    request = urllib.request.Request(
        f"{loki_url.rstrip('/')}/loki/api/v1/query_range?{params}",
        headers={"Accept": "application/json"},
    )
    with urllib.request.urlopen(request, timeout=15) as response:
        payload = cast(LokiResponse, json.load(response))
    if payload.get("status") != "success":
        raise RuntimeError(f"Loki query failed for {query}: {payload}")
    return parse_loki_events(payload)


def build_node_map(snapshots: Sequence[Event]) -> dict[str, NodeMetadata]:
    mapping: dict[str, NodeMetadata] = {}
    for event in snapshots:
        timestamp_ns = event_int(event, "_timestamp_ns")
        metadata = NodeMetadata(
            node=event_str(event, "node", event_str(event, "name", "unknown")),
            user=event_str(event, "user", event_str(event, "username")),
            tags=event_str_list(event, "tags"),
            online=event_bool(event, "online"),
            health=event_str(event, "health"),
            last_seen_seconds=event_int(event, "last_seen_seconds")
            if "last_seen_seconds" in event
            else None,
            snapshot_timestamp_ns=timestamp_ns,
        )
        for address in event_str_list(event, "ip_addresses"):
            previous = mapping.get(address)
            if previous is None or previous.snapshot_timestamp_ns <= timestamp_ns:
                mapping[address] = metadata
    return mapping


def classify_access(nginx_event: Event, nodes_by_ip: dict[str, NodeMetadata]) -> Event:
    source_ip = event_str(nginx_event, "source_ip")
    target_host = event_str(nginx_event, "host", "unknown")
    service = event_str(nginx_event, "service", "unknown")
    source_node = nodes_by_ip.get(source_ip)
    audit: Event = {
        "emitter_host": "rho",
        "log_type": "access_audit",
        "event": "tailnet_app_access",
        "source_ip": source_ip,
        "service": service,
        "target_host": target_host,
        "http_method": event_str(nginx_event, "http_method", "unknown"),
        "request_path": event_str(nginx_event, "request_path"),
        "status": event_int(nginx_event, "status"),
        "request_id": event_str(nginx_event, "request_id"),
        "user_agent": event_str(nginx_event, "user_agent"),
        "ingress_network": "tailnet",
        "status_class": status_class(event_str(nginx_event, "status")),
        "source_kind": "unknown",
        "correlation_status": "unmatched",
        "correlation_delta_seconds": None,
        "_timestamp_ns": event_int(nginx_event, "_timestamp_ns"),
    }
    if source_node is not None:
        delta = (
            event_int(nginx_event, "_timestamp_ns") - source_node.snapshot_timestamp_ns
        ) / 1_000_000_000
        audit.update(
            {
                "source_kind": "headscale_node",
                "source_node": source_node.node,
                "source_headscale_user": source_node.user,
                "source_tags": cast(list[JsonValue], source_node.tags),
                "source_online": source_node.online,
                "source_health": source_node.health,
                "source_last_seen_seconds": source_node.last_seen_seconds,
                "correlation_status": "matched",
                "correlation_delta_seconds": round(delta, 3),
            }
        )
    return audit


def event_labels(event: Event) -> dict[str, str]:
    event_name = event_str(event, "event", "tailnet_app_access")
    labels = {
        "host": event_str(event, "target_host", event_str(event, "emitter_host", "unknown")),
        "log_type": "access_audit",
        "event": event_name,
    }
    if event_name == "correlator_heartbeat":
        labels["correlator"] = event_str(event, "correlator", "unknown")
        labels["status"] = event_str(event, "status", "unknown")
        return labels
    labels.update(
        {
            "service": event_str(event, "service", "unknown"),
            "ingress_network": "tailnet",
            "source_kind": event_str(event, "source_kind", "unknown"),
            "status_class": event_str(event, "status_class", "unknown"),
        }
    )
    return labels


def clean_event(event: Event) -> Event:
    return {key: value for key, value in event.items() if not key.startswith("_")}


def push_events(loki_url: str, events: Sequence[Event]) -> None:
    grouped: dict[tuple[tuple[str, str], ...], PushStream] = {}
    for event in events:
        labels = event_labels(event)
        labels_key = tuple(sorted(labels.items()))
        stream = grouped.setdefault(labels_key, {"stream": labels, "values": []})
        stream["values"].append(
            [
                str(event_int(event, "_timestamp_ns", time.time_ns())),
                json.dumps(clean_event(event), sort_keys=True),
            ]
        )
    request = urllib.request.Request(
        f"{loki_url.rstrip('/')}/loki/api/v1/push",
        data=json.dumps({"streams": list(grouped.values())}).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=15) as response:
        response.read()


def load_state(path: Path, ttl_seconds: int, now: float) -> State:
    try:
        with path.open("r", encoding="utf-8") as handle:
            state = cast(State, json.load(handle))
    except (FileNotFoundError, json.JSONDecodeError):
        state = {"seen": {}}
    state["seen"] = {
        key: seen_at
        for key, seen_at in state.get("seen", {}).items()
        if now - seen_at <= ttl_seconds
    }
    return state


def save_state(path: Path, state: State) -> None:
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    tmp = path.with_suffix(f"{path.suffix}.tmp")
    with tmp.open("w", encoding="utf-8") as handle:
        json.dump(state, handle, sort_keys=True)
    tmp.replace(path)


def dedup_key(event: Event) -> str:
    parts = [
        event_str(event, "_timestamp_ns"),
        event_str(event, "source_ip"),
        event_str(event, "target_host"),
        event_str(event, "service"),
        event_str(event, "http_method"),
        event_str(event, "request_path"),
        event_str(event, "status"),
        event_str(event, "request_id"),
    ]
    return "|".join(parts)


def heartbeat_event(
    *,
    queried_nginx_events: int,
    tailnet_nginx_events: int,
    snapshot_events: int,
    emitted_events: int,
) -> Event:
    return {
        "emitter_host": "rho",
        "target_host": "rho",
        "log_type": "access_audit",
        "event": "correlator_heartbeat",
        "correlator": "tailnet_app_access",
        "status": "ok",
        "queried_nginx_events": queried_nginx_events,
        "tailnet_nginx_events": tailnet_nginx_events,
        "snapshot_events": snapshot_events,
        "emitted_events": emitted_events,
        "_timestamp_ns": time.time_ns(),
    }


def run(args: CliArgs) -> int:
    nginx_events = query_loki(
        args["loki_url"],
        '{log_type="nginx_access", ingress_network=~"tailnet|unknown"}',
        args["nginx_window_seconds"],
        args["query_limit"],
    )
    snapshots = query_loki(
        args["loki_url"],
        '{log_type="headscale_nodes", event="node_snapshot"}',
        args["headscale_window_seconds"],
        args["query_limit"],
    )
    nodes_by_ip = build_node_map(snapshots)
    now = time.time()
    state = load_state(args["state"], args["seen_ttl_seconds"], now)
    new_events: list[Event] = []
    new_keys: list[str] = []
    tailnet_event_count = 0
    for nginx_event in nginx_events:
        if not is_tailnet_access(nginx_event):
            continue
        tailnet_event_count += 1
        audit_event = classify_access(nginx_event, nodes_by_ip)
        key = dedup_key(audit_event)
        if key in state["seen"]:
            continue
        new_events.append(audit_event)
        new_keys.append(key)
    audit_events = new_events + [
        heartbeat_event(
            queried_nginx_events=len(nginx_events),
            tailnet_nginx_events=tailnet_event_count,
            snapshot_events=len(snapshots),
            emitted_events=len(new_events),
        )
    ]
    if args["dry_run"]:
        for event in audit_events:
            print(json.dumps(clean_event(event), sort_keys=True))
        return 0
    push_events(args["loki_url"], audit_events)
    for key in new_keys:
        state["seen"][key] = now
    save_state(args["state"], state)
    return 0


def run_self_tests() -> int:
    assert status_class(200) == "2xx"
    assert status_class("302") == "3xx"
    assert status_class("404") == "4xx"
    assert status_class(503) == "5xx"
    assert status_class("oops") == "unknown"
    assert is_tailnet_ip("100.64.0.1")
    assert is_tailnet_ip("100.127.255.254")
    assert not is_tailnet_ip("100.128.0.1")
    nodes = build_node_map(
        [
            {
                "node": "phone",
                "user": "alice",
                "tags": "tag:mobile,tag:trusted",
                "online": "true",
                "ip_addresses": "100.64.0.9,100.64.0.10",
                "_timestamp_ns": 100,
            }
        ]
    )
    assert nodes["100.64.0.9"].node == "phone"
    assert nodes["100.64.0.10"].tags == ["tag:mobile", "tag:trusted"]
    assert nodes["100.64.0.10"].online is True
    matched = classify_access(
        {
            "host": "vault.sjanglab.org",
            "service": "vaultwarden",
            "source_ip": "100.64.0.9",
            "status": 200,
            "_timestamp_ns": 200,
        },
        nodes,
    )
    assert matched["source_kind"] == "headscale_node"
    assert matched["source_node"] == "phone"
    unmatched = classify_access(
        {
            "host": "vault.sjanglab.org",
            "service": "vaultwarden",
            "source_ip": "100.64.0.99",
            "status": 404,
            "_timestamp_ns": 300,
        },
        nodes,
    )
    assert unmatched["source_kind"] == "unknown"
    assert unmatched["correlation_status"] == "unmatched"
    assert dedup_key(matched) == dedup_key(dict(matched))

    heartbeat = heartbeat_event(
        queried_nginx_events=4,
        tailnet_nginx_events=3,
        snapshot_events=2,
        emitted_events=1,
    )
    assert event_labels(heartbeat) == {
        "host": "rho",
        "log_type": "access_audit",
        "event": "correlator_heartbeat",
        "correlator": "tailnet_app_access",
        "status": "ok",
    }
    print("self-tests passed")
    return 0


def parse_args(argv: Sequence[str]) -> CliArgs:
    parser = argparse.ArgumentParser(
        description="Correlate tailnet nginx access with Headscale inventory"
    )
    parser.add_argument("--loki-url", required=False)
    parser.add_argument(
        "--state", type=Path, default=Path("/var/lib/tailnet-app-access-audit/seen.json")
    )
    parser.add_argument("--nginx-window-seconds", type=int, default=300)
    parser.add_argument("--headscale-window-seconds", type=int, default=1800)
    parser.add_argument("--seen-ttl-seconds", type=int, default=24 * 60 * 60)
    parser.add_argument("--query-limit", type=int, default=5000)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--self-test", action="store_true")
    namespace = parser.parse_args(argv)
    if namespace.self_test:
        return {
            "loki_url": "http://127.0.0.1:3100",
            "state": namespace.state,
            "nginx_window_seconds": namespace.nginx_window_seconds,
            "headscale_window_seconds": namespace.headscale_window_seconds,
            "seen_ttl_seconds": namespace.seen_ttl_seconds,
            "query_limit": namespace.query_limit,
            "dry_run": namespace.dry_run,
            "self_test": True,
        }
    if namespace.loki_url is None:
        parser.error("--loki-url is required unless --self-test is used")
    return {
        "loki_url": namespace.loki_url,
        "state": namespace.state,
        "nginx_window_seconds": namespace.nginx_window_seconds,
        "headscale_window_seconds": namespace.headscale_window_seconds,
        "seen_ttl_seconds": namespace.seen_ttl_seconds,
        "query_limit": namespace.query_limit,
        "dry_run": namespace.dry_run,
    }


def main(argv: Sequence[str]) -> int:
    args = parse_args(argv)
    if args.get("self_test", False):
        return run_self_tests()
    return run(args)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
