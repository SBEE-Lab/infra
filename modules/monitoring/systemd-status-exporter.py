#!/usr/bin/env python3
import argparse
import json
import subprocess
import time
from typing import Any

SERVICE_PROPERTIES = [
    "Description",
    "LoadState",
    "ActiveState",
    "SubState",
    "Result",
    "ExecMainStatus",
    "ExecMainStartTimestamp",
    "ExecMainExitTimestamp",
    "NRestarts",
]
TIMER_PROPERTIES = [
    "LoadState",
    "ActiveState",
    "LastTriggerUSec",
    "NextElapseUSecRealtime",
    "Result",
]


def systemctl_show(systemctl: str, unit: str, properties: list[str]) -> dict[str, str]:
    command = [systemctl, "show", "--timestamp=unix", unit]
    command += [argument for prop in properties for argument in ("--property", prop)]
    result = subprocess.run(
        command,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    return dict(line.split("=", 1) for line in result.stdout.splitlines() if "=" in line)


def unix_timestamp(value: str) -> int | None:
    if value in ("", "0", "n/a"):
        return None
    try:
        return int(float(value.removeprefix("@")))
    except ValueError:
        return None


def age_seconds(now: int, value: str) -> int | None:
    timestamp = unix_timestamp(value)
    return None if timestamp is None else max(0, now - timestamp)


def seconds_until(now: int, value: str) -> int | None:
    timestamp = unix_timestamp(value)
    return None if timestamp is None else timestamp - now


def health(
    result: str, exit_status: str, last_success_age: int | None, max_success_age: int
) -> tuple[str, str]:
    if result not in ("", "success") or exit_status not in ("", "0"):
        return "FAIL", "failed"
    if last_success_age is None:
        return "WARN", "never_succeeded"
    if last_success_age > max_success_age:
        return "WARN", "stale_success"
    return "OK", "ok"


def unit_snapshot(
    *,
    host: str,
    unit_spec: dict[str, Any],
    now: int,
    systemctl: str,
) -> dict[str, object]:
    unit = str(unit_spec["unit"])
    max_success_age = int(unit_spec["max_success_age_seconds"])
    service = systemctl_show(systemctl, unit, SERVICE_PROPERTIES)
    timer = systemctl_show(systemctl, unit.replace(".service", ".timer"), TIMER_PROPERTIES)
    result = service.get("Result", "")
    exit_status = service.get("ExecMainStatus", "")
    last_exit_age = age_seconds(now, service.get("ExecMainExitTimestamp", ""))
    last_success_age = last_exit_age if result == "success" and exit_status in ("", "0") else None
    health_status, health_reason = health(result, exit_status, last_success_age, max_success_age)

    event = {
        "host": host,
        "log_type": "systemd_status",
        "event": "job_snapshot",
        "unit": unit,
        "description": service.get("Description", ""),
        "job_class": str(unit_spec.get("job_class", "unknown")),
        "trigger_kind": str(unit_spec.get("trigger_kind", "unknown")),
        "alert_enabled": bool(unit_spec.get("alert_enabled", False)),
        "load_state": service.get("LoadState", ""),
        "active_state": service.get("ActiveState", ""),
        "sub_state": service.get("SubState", ""),
        "result": result,
        "last_exit_status": exit_status,
        "restart_count": service.get("NRestarts", ""),
        "timer_load_state": timer.get("LoadState", ""),
        "timer_active_state": timer.get("ActiveState", ""),
        "timer_result": timer.get("Result", ""),
        "last_start_age_seconds": age_seconds(now, service.get("ExecMainStartTimestamp", "")),
        "last_exit_age_seconds": last_exit_age,
        "last_trigger_age_seconds": age_seconds(now, timer.get("LastTriggerUSec", "")),
        "last_success_age_seconds": last_success_age,
        "next_due_seconds": seconds_until(now, timer.get("NextElapseUSecRealtime", "")),
        "max_success_age_seconds": max_success_age,
        "health": health_status,
        "health_reason": health_reason,
    }
    event["message"] = (
        f"{unit}: {event['health']} ({event['health_reason']}) "
        f"{event['active_state']}/{event['sub_state']} result={event['result']} "
        f"exit={event['last_exit_status']} "
        f"last_success_age={event['last_success_age_seconds']}"
    )
    return event


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", required=True)
    parser.add_argument("--units-json", required=True)
    parser.add_argument("--systemctl", required=True)
    args = parser.parse_args()

    now = int(time.time())
    for unit_spec in json.loads(args.units_json):
        if isinstance(unit_spec, str):
            unit_spec = {
                "unit": unit_spec,
                "job_class": "unknown",
                "trigger_kind": "unknown",
                "alert_enabled": False,
                "max_success_age_seconds": 45 * 24 * 3600,
            }
        print(
            json.dumps(
                unit_snapshot(
                    host=args.host,
                    unit_spec=unit_spec,
                    now=now,
                    systemctl=args.systemctl,
                ),
                sort_keys=True,
            )
        )


if __name__ == "__main__":
    main()
