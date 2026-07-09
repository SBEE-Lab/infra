#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
import time
import urllib.parse
import urllib.request
from dataclasses import dataclass
from ipaddress import IPv4Address, ip_address
from pathlib import Path
from typing import NotRequired, Sequence, TypedDict, cast

JsonValue = None | bool | int | float | str | list["JsonValue"] | dict[str, "JsonValue"]
Event = dict[str, JsonValue]


class AdminPeer(TypedDict):
    device: str
    owner: str


class InventoryJson(TypedDict):
    hosts: dict[str, str]
    admin_peers: dict[str, AdminPeer]
    bastion_host: str
    bastion_ip: str
    emergency_lan_ranges: list[str]


class LokiValue(TypedDict):
    stream: dict[str, str]
    values: list[list[str]]


class LokiData(TypedDict):
    result: list[LokiValue]


class LokiResponse(TypedDict):
    status: str
    data: LokiData


class PushStream(TypedDict):
    stream: dict[str, str]
    values: list[list[str]]


class PushPayload(TypedDict):
    streams: list[PushStream]


class State(TypedDict):
    seen: dict[str, float]


class CliArgs(TypedDict):
    inventory: Path
    loki_url: str
    state: Path
    ssh_window_seconds: int
    bastion_window_seconds: int
    seen_ttl_seconds: int
    query_limit: int
    dry_run: bool
    self_test: NotRequired[bool]


@dataclass(frozen=True)
class EmergencyRange:
    start: IPv4Address
    end: IPv4Address

    def contains(self, value: str) -> bool:
        try:
            candidate = ip_address(value)
        except ValueError:
            return False
        return isinstance(candidate, IPv4Address) and self.start <= candidate <= self.end


@dataclass(frozen=True)
class Inventory:
    hosts: dict[str, str]
    host_by_ip: dict[str, str]
    admin_peers: dict[str, AdminPeer]
    bastion_host: str
    bastion_ip: str
    emergency_lan_ranges: list[EmergencyRange]


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


def parse_emergency_range(raw_range: str) -> EmergencyRange:
    start, end = raw_range.split("-", 1)
    start_ip = ip_address(start)
    end_ip = ip_address(end)
    if not isinstance(start_ip, IPv4Address) or not isinstance(end_ip, IPv4Address):
        raise ValueError(f"only IPv4 emergency ranges are supported: {raw_range}")
    return EmergencyRange(start_ip, end_ip)


def load_inventory(path: Path) -> Inventory:
    with path.open("r", encoding="utf-8") as handle:
        raw = cast(InventoryJson, json.load(handle))

    hosts = raw["hosts"]
    return Inventory(
        hosts=hosts,
        host_by_ip={ip: host for host, ip in hosts.items()},
        admin_peers=raw["admin_peers"],
        bastion_host=raw["bastion_host"],
        bastion_ip=raw["bastion_ip"],
        emergency_lan_ranges=[parse_emergency_range(item) for item in raw["emergency_lan_ranges"]],
    )


def is_emergency_lan(source_ip: str, inventory: Inventory) -> bool:
    return any(raw_range.contains(source_ip) for raw_range in inventory.emergency_lan_ranges)


def is_public_ip(source_ip: str) -> bool:
    try:
        return ip_address(source_ip).is_global
    except ValueError:
        return False


def base_audit_event(ssh_event: Event, inventory: Inventory) -> Event:
    target_host = event_str(ssh_event, "host", "unknown")
    target_ip = inventory.hosts.get(target_host, "")
    source_ip = event_str(ssh_event, "source_ip")

    return {
        "emitter_host": "rho",
        "log_type": "access_audit",
        "event": "ssh_login",
        "target_host": target_host,
        "target_ip": target_ip,
        "target_network": "wg-admin" if target_ip else "unknown",
        "source_ip": source_ip,
        "source_port": event_str(ssh_event, "source_port"),
        "ssh_user": event_str(ssh_event, "user"),
        "auth_method": event_str(ssh_event, "auth_method"),
        "key_type": event_str(ssh_event, "key_type"),
        "key_fingerprint": event_str(ssh_event, "key_fingerprint"),
        "path": "unknown",
        "source_kind": "unknown",
        "ingress_network": "local_lan" if is_emergency_lan(source_ip, inventory) else "unknown",
        "correlation_status": "unmatched",
        "correlation_delta_seconds": None,
    }


def matching_bastion_events(
    ssh_event: Event, bastion_events: Sequence[Event]
) -> list[tuple[float, Event]]:
    target_host = event_str(ssh_event, "host")
    source_port = event_str(ssh_event, "source_port")
    ssh_timestamp = event_int(ssh_event, "_timestamp_ns")
    matches: list[tuple[float, Event]] = []

    for bastion_event in bastion_events:
        if event_str(bastion_event, "target_host") != target_host:
            continue
        if event_str(bastion_event, "bastion_local_port") != source_port:
            continue

        bastion_timestamp = event_int(bastion_event, "_timestamp_ns")
        delta = (ssh_timestamp - bastion_timestamp) / 1_000_000_000
        if abs(delta) <= 120:
            matches.append((delta, bastion_event))

    matches.sort(key=lambda item: (abs(item[0]), event_int(item[1], "_timestamp_ns")))
    return matches


def matching_bastion_leg_login(bastion_event: Event, eta_logins: Sequence[Event]) -> Event | None:
    source_ip = event_str(bastion_event, "source_ip")
    source_port = event_str(bastion_event, "source_port")
    bastion_timestamp = event_int(bastion_event, "_timestamp_ns")
    candidates: list[tuple[float, Event]] = []

    for eta_login in eta_logins:
        if event_str(eta_login, "source_ip") != source_ip:
            continue
        if event_str(eta_login, "source_port") != source_port:
            continue
        delta = (event_int(eta_login, "_timestamp_ns") - bastion_timestamp) / 1_000_000_000
        if abs(delta) <= 600:
            candidates.append((delta, eta_login))

    if not candidates:
        return None
    candidates.sort(key=lambda item: (abs(item[0]), event_int(item[1], "_timestamp_ns")))
    return candidates[0][1]


def update_origin_classification(
    audit_event: Event, source_ip: str, inventory: Inventory, *, via_bastion: bool
) -> None:
    suffix = "_to_bastion_then_wg-admin" if via_bastion else ""

    admin_peer = inventory.admin_peers.get(source_ip)
    if admin_peer is not None:
        audit_event.update(
            {
                "source_kind": "admin_peer",
                "ingress_network": f"wg-admin{suffix}",
                "source_device": admin_peer["device"],
                "source_owner": admin_peer["owner"],
            }
        )
        return

    source_host = inventory.host_by_ip.get(source_ip)
    if source_host is not None:
        audit_event.update(
            {
                "source_kind": "managed_host",
                "ingress_network": f"wg-admin{suffix}",
                "source_host": source_host,
            }
        )
        return

    if is_emergency_lan(source_ip, inventory):
        audit_event.update(
            {
                "source_kind": "unknown",
                "ingress_network": f"local_lan{suffix}",
            }
        )
        return

    if is_public_ip(source_ip):
        audit_event.update(
            {
                "source_kind": "public_ip",
                "ingress_network": f"public{suffix}",
            }
        )


def apply_bastion_classification(
    audit_event: Event,
    ssh_event: Event,
    bastion_matches: Sequence[tuple[float, Event]],
    eta_logins: Sequence[Event],
    inventory: Inventory,
) -> bool:
    if event_str(ssh_event, "source_ip") != inventory.bastion_ip:
        return False
    if not bastion_matches:
        return False

    delta, bastion_event = bastion_matches[0]
    bastion_source_ip = event_str(bastion_event, "source_ip")
    audit_event.update(
        {
            "path": "bastion",
            "external_source_ip": bastion_source_ip,
            "external_source_port": event_str(bastion_event, "source_port"),
            "bastion_host": inventory.bastion_host,
            "bastion_user": event_str(bastion_event, "bastion_user"),
            "bastion_local_ip": event_str(bastion_event, "bastion_local_ip"),
            "bastion_local_port": event_str(bastion_event, "bastion_local_port"),
            "correlation_status": "ambiguous" if len(bastion_matches) > 1 else "matched",
            "correlation_delta_seconds": round(delta, 3),
        }
    )
    update_origin_classification(audit_event, bastion_source_ip, inventory, via_bastion=True)

    bastion_login = matching_bastion_leg_login(bastion_event, eta_logins)
    if bastion_login is not None:
        audit_event.update(
            {
                "bastion_auth_method": event_str(bastion_login, "auth_method"),
                "bastion_key_type": event_str(bastion_login, "key_type"),
                "bastion_key_fingerprint": event_str(bastion_login, "key_fingerprint"),
                "bastion_ssh_user": event_str(bastion_login, "user"),
            }
        )
    return True


def classify_login(
    ssh_event: Event,
    bastion_events: Sequence[Event],
    eta_logins: Sequence[Event],
    inventory: Inventory,
) -> Event:
    audit_event = base_audit_event(ssh_event, inventory)
    source_ip = event_str(ssh_event, "source_ip")
    target_host = event_str(ssh_event, "host")

    bastion_matches = matching_bastion_events(ssh_event, bastion_events)
    if apply_bastion_classification(
        audit_event, ssh_event, bastion_matches, eta_logins, inventory
    ):
        return audit_event

    admin_peer = inventory.admin_peers.get(source_ip)
    if admin_peer is not None:
        audit_event.update(
            {
                "path": "direct",
                "source_kind": "admin_peer",
                "ingress_network": "wg-admin",
                "source_device": admin_peer["device"],
                "source_owner": admin_peer["owner"],
            }
        )
        return audit_event

    source_host = inventory.host_by_ip.get(source_ip)
    if source_host is not None:
        audit_event.update(
            {
                "path": "machine_to_machine",
                "source_kind": "managed_host",
                "ingress_network": "wg-admin",
                "source_host": source_host,
            }
        )
        return audit_event

    if target_host == inventory.bastion_host and is_public_ip(source_ip):
        audit_event.update(
            {
                "path": "public_bastion_login",
                "source_kind": "public_ip",
                "ingress_network": "public",
            }
        )
        return audit_event

    return audit_event


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


def event_labels(event: Event) -> dict[str, str]:
    return {
        "host": event_str(event, "target_host", "unknown"),
        "log_type": "access_audit",
        "event": "ssh_login",
        "path": event_str(event, "path", "unknown"),
        "ingress_network": event_str(event, "ingress_network", "unknown"),
        "source_kind": event_str(event, "source_kind", "unknown"),
    }


def clean_event(event: Event) -> Event:
    return {key: value for key, value in event.items() if not key.startswith("_")}


def push_events(loki_url: str, events: Sequence[Event]) -> None:
    grouped: dict[tuple[tuple[str, str], ...], PushStream] = {}
    for event in events:
        labels = event_labels(event)
        labels_key = tuple(sorted(labels.items()))
        stream = grouped.setdefault(labels_key, {"stream": labels, "values": []})
        timestamp = str(event_int(event, "_timestamp_ns", time.time_ns()))
        stream["values"].append([timestamp, json.dumps(clean_event(event), sort_keys=True)])

    payload: PushPayload = {"streams": list(grouped.values())}
    request = urllib.request.Request(
        f"{loki_url.rstrip('/')}/loki/api/v1/push",
        data=json.dumps(payload).encode("utf-8"),
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
        event_str(event, "target_host"),
        event_str(event, "ssh_user"),
        event_str(event, "source_ip"),
        event_str(event, "source_port"),
        event_str(event, "key_fingerprint"),
    ]
    return "|".join(parts)


def classify_events(
    ssh_events: Sequence[Event], bastion_events: Sequence[Event], inventory: Inventory
) -> list[Event]:
    eta_logins = [
        event for event in ssh_events if event_str(event, "host") == inventory.bastion_host
    ]
    classified = [
        classify_login(event, bastion_events, eta_logins, inventory) for event in ssh_events
    ]
    for audit_event, ssh_event in zip(classified, ssh_events, strict=True):
        audit_event["_timestamp_ns"] = event_int(ssh_event, "_timestamp_ns")
    return classified


def run(args: CliArgs) -> int:
    inventory = load_inventory(args["inventory"])
    ssh_events = query_loki(
        args["loki_url"],
        '{log_type="ssh", event="login_success"}',
        args["ssh_window_seconds"],
        args["query_limit"],
    )
    bastion_events = query_loki(
        args["loki_url"],
        '{log_type="ssh_bastion", event="bastion_forward"}',
        args["bastion_window_seconds"],
        args["query_limit"],
    )

    now = time.time()
    state = load_state(args["state"], args["seen_ttl_seconds"], now)
    new_events: list[Event] = []
    new_keys: list[str] = []
    for event in classify_events(ssh_events, bastion_events, inventory):
        key = dedup_key(event)
        if key in state["seen"]:
            continue
        new_events.append(event)
        new_keys.append(key)

    if args["dry_run"]:
        for event in new_events:
            print(json.dumps(clean_event(event), sort_keys=True))
        return 0

    if new_events:
        push_events(args["loki_url"], new_events)

    for key in new_keys:
        state["seen"][key] = now
    save_state(args["state"], state)
    return 0


def sample_inventory() -> Inventory:
    return Inventory(
        hosts={"eta": "10.100.0.1", "psi": "10.100.0.2", "rho": "10.100.0.3", "tau": "10.100.0.4"},
        host_by_ip={
            "10.100.0.1": "eta",
            "10.100.0.2": "psi",
            "10.100.0.3": "rho",
            "10.100.0.4": "tau",
        },
        admin_peers={"10.100.0.200": {"device": "seungwon-rhesus", "owner": "seungwon"}},
        bastion_host="eta",
        bastion_ip="10.100.0.1",
        emergency_lan_ranges=[parse_emergency_range("10.80.169.38-10.80.169.40")],
    )


def ssh_sample(
    *,
    host: str,
    source_ip: str,
    source_port: str = "50000",
    timestamp_ns: int = 1_000_000_000,
    user: str = "seungwon",
    key_fingerprint: str = "SHA256:target",
) -> Event:
    return {
        "host": host,
        "user": user,
        "source_ip": source_ip,
        "source_port": source_port,
        "auth_method": "publickey",
        "key_type": "ED25519",
        "key_fingerprint": key_fingerprint,
        "_timestamp_ns": timestamp_ns,
    }


def bastion_sample(
    *,
    target_host: str = "psi",
    bastion_local_port: str = "45555",
    timestamp_ns: int = 1_010_000_000,
    source_ip: str = "203.0.113.10",
    source_port: str = "44444",
) -> Event:
    return {
        "host": "eta",
        "target_host": target_host,
        "target_ip": "10.100.0.2",
        "bastion_user": "seungwon",
        "source_ip": source_ip,
        "source_port": source_port,
        "bastion_local_ip": "10.100.0.1",
        "bastion_local_port": bastion_local_port,
        "_timestamp_ns": timestamp_ns,
    }


def run_self_tests() -> int:
    inventory = sample_inventory()

    direct = classify_login(ssh_sample(host="rho", source_ip="10.100.0.200"), [], [], inventory)
    assert direct["path"] == "direct"
    assert direct["source_kind"] == "admin_peer"
    assert direct["source_device"] == "seungwon-rhesus"

    machine = classify_login(ssh_sample(host="rho", source_ip="10.100.0.2"), [], [], inventory)
    assert machine["path"] == "machine_to_machine"
    assert machine["source_host"] == "psi"

    target_login = ssh_sample(
        host="psi", source_ip="10.100.0.1", source_port="45555", timestamp_ns=1_000_000_000
    )
    eta_login = ssh_sample(
        host="eta",
        source_ip="203.0.113.10",
        source_port="44444",
        timestamp_ns=950_000_000,
        key_fingerprint="SHA256:bastion",
    )
    matched = classify_login(target_login, [bastion_sample()], [eta_login], inventory)
    assert matched["path"] == "bastion"
    assert matched["correlation_status"] == "matched"
    assert matched["external_source_ip"] == "203.0.113.10"
    assert matched["source_kind"] == "unknown"
    assert matched["ingress_network"] == "unknown"
    assert matched["key_fingerprint"] == "SHA256:target"
    assert matched["bastion_key_fingerprint"] == "SHA256:bastion"

    admin_bastion = classify_login(
        target_login,
        [bastion_sample(source_ip="10.100.0.200")],
        [ssh_sample(host="eta", source_ip="10.100.0.200", source_port="44444")],
        inventory,
    )
    assert admin_bastion["path"] == "bastion"
    assert admin_bastion["source_kind"] == "admin_peer"
    assert admin_bastion["ingress_network"] == "wg-admin_to_bastion_then_wg-admin"
    assert admin_bastion["source_device"] == "seungwon-rhesus"

    public_bastion_jump = classify_login(
        target_login, [bastion_sample(source_ip="8.8.8.8")], [], inventory
    )
    assert public_bastion_jump["path"] == "bastion"
    assert public_bastion_jump["source_kind"] == "public_ip"
    assert public_bastion_jump["ingress_network"] == "public_to_bastion_then_wg-admin"

    ambiguous = classify_login(
        target_login,
        [
            bastion_sample(timestamp_ns=1_010_000_000, source_ip="203.0.113.10"),
            bastion_sample(timestamp_ns=990_000_000, source_ip="203.0.113.11"),
        ],
        [],
        inventory,
    )
    assert ambiguous["path"] == "bastion"
    assert ambiguous["correlation_status"] == "ambiguous"
    assert ambiguous["external_source_ip"] == "203.0.113.11"

    public_bastion = classify_login(ssh_sample(host="eta", source_ip="8.8.8.8"), [], [], inventory)
    assert public_bastion["path"] == "public_bastion_login"
    assert public_bastion["ingress_network"] == "public"

    private_bastion = classify_login(
        ssh_sample(host="eta", source_ip="10.1.2.3"), [], [], inventory
    )
    assert private_bastion["path"] == "unknown"
    assert private_bastion["ingress_network"] == "unknown"

    unknown = classify_login(ssh_sample(host="psi", source_ip="198.51.100.20"), [], [], inventory)
    assert unknown["path"] == "unknown"
    assert unknown["ingress_network"] == "unknown"

    emergency = classify_login(ssh_sample(host="rho", source_ip="10.80.169.39"), [], [], inventory)
    assert emergency["path"] == "unknown"
    assert emergency["ingress_network"] == "local_lan"

    print("self-tests passed")
    return 0


def parse_args(argv: Sequence[str]) -> CliArgs:
    parser = argparse.ArgumentParser(description="Correlate raw SSH logs into access audit events")
    parser.add_argument("--inventory", type=Path, required=False)
    parser.add_argument("--loki-url", required=False)
    parser.add_argument("--state", type=Path, default=Path("/var/lib/ssh-access-audit/seen.json"))
    parser.add_argument("--ssh-window-seconds", type=int, default=300)
    parser.add_argument("--bastion-window-seconds", type=int, default=600)
    parser.add_argument("--seen-ttl-seconds", type=int, default=24 * 60 * 60)
    parser.add_argument("--query-limit", type=int, default=5000)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--self-test", action="store_true")
    namespace = parser.parse_args(argv)

    if namespace.self_test:
        return {
            "inventory": Path("/dev/null"),
            "loki_url": "http://127.0.0.1:3100",
            "state": namespace.state,
            "ssh_window_seconds": namespace.ssh_window_seconds,
            "bastion_window_seconds": namespace.bastion_window_seconds,
            "seen_ttl_seconds": namespace.seen_ttl_seconds,
            "query_limit": namespace.query_limit,
            "dry_run": namespace.dry_run,
            "self_test": True,
        }

    if namespace.inventory is None or namespace.loki_url is None:
        parser.error("--inventory and --loki-url are required unless --self-test is used")

    return {
        "inventory": namespace.inventory,
        "loki_url": namespace.loki_url,
        "state": namespace.state,
        "ssh_window_seconds": namespace.ssh_window_seconds,
        "bastion_window_seconds": namespace.bastion_window_seconds,
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
