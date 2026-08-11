#!/usr/bin/env python3
import argparse
import base64
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any

LIST_FIELDS = ("emails", "members")
SCALAR_FIELDS = ("description",)
SUPPORTED_TYPES = {"domain", "individual", "list"}


def normalize_principal(principal: dict[str, Any]) -> dict[str, Any]:
    normalized: dict[str, Any] = {
        "type": principal.get("type"),
        "name": principal.get("name"),
    }
    for field in SCALAR_FIELDS:
        if field in principal:
            normalized[field] = principal[field] or ""
    for field in LIST_FIELDS:
        if field in principal:
            value = principal[field] or []
            if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
                raise ValueError(f"{principal.get('name')}: {field} must be a list of strings")
            normalized[field] = sorted(set(value))
    return normalized


def validate_desired(principals: list[dict[str, Any]]) -> list[dict[str, Any]]:
    names: set[str] = set()
    emails: set[str] = set()
    normalized = []
    for raw in principals:
        principal = normalize_principal(raw)
        name = principal["name"]
        principal_type = principal["type"]
        if not isinstance(name, str) or not name:
            raise ValueError("principal name must be a non-empty string")
        if principal_type not in SUPPORTED_TYPES:
            raise ValueError(f"{name}: unsupported principal type {principal_type!r}")
        if name in names:
            raise ValueError(f"duplicate principal name: {name}")
        names.add(name)
        for email in principal.get("emails", []):
            folded = email.casefold()
            if folded in emails:
                raise ValueError(f"duplicate email: {email}")
            emails.add(folded)
        normalized.append(principal)
    return normalized


def build_patch(current: dict[str, Any], desired: dict[str, Any]) -> list[dict[str, Any]]:
    current_normalized = normalize_principal(current)
    desired_normalized = normalize_principal(desired)
    if current_normalized["type"] != desired_normalized["type"]:
        raise ValueError(
            f"{desired_normalized['name']}: type mismatch: "
            f"current={current_normalized['type']!r}, desired={desired_normalized['type']!r}"
        )

    patch = []
    for field in (*SCALAR_FIELDS, *LIST_FIELDS):
        if (
            field in desired_normalized
            and current_normalized.get(field) != desired_normalized[field]
        ):
            patch.append({"action": "set", "field": field, "value": desired_normalized[field]})
    return patch


class StalwartClient:
    def __init__(self, api_url: str, username: str, password: str) -> None:
        self.api_url = api_url.rstrip("/")
        credentials = base64.b64encode(f"{username}:{password}".encode()).decode()
        self.headers = {
            "Authorization": f"Basic {credentials}",
            "Accept": "application/json",
        }

    def request(self, method: str, path: str, body: Any | None = None) -> Any:
        data = None if body is None else json.dumps(body, separators=(",", ":")).encode()
        headers = dict(self.headers)
        if data is not None:
            headers["Content-Type"] = "application/json"
        request = urllib.request.Request(
            f"{self.api_url}{path}", data=data, headers=headers, method=method
        )
        for attempt in range(30):
            try:
                with urllib.request.urlopen(request, timeout=30) as response:
                    payload = response.read()
                break
            except urllib.error.HTTPError as error:
                if error.code == 404:
                    return None
                detail = error.read().decode(errors="replace")
                raise RuntimeError(
                    f"{method} {path} failed with HTTP {error.code}: {detail}"
                ) from error
            except urllib.error.URLError:
                if attempt == 29:
                    raise
                time.sleep(1)
        parsed = json.loads(payload) if payload else None
        if isinstance(parsed, dict) and parsed.get("error") == "notFound":
            return None
        if isinstance(parsed, dict) and "data" in parsed:
            return parsed["data"]
        return parsed

    def get_principal(self, name: str) -> dict[str, Any] | None:
        result = self.request("GET", f"/principal/{urllib.parse.quote(name, safe='')}")
        if result is not None and not isinstance(result, dict):
            raise RuntimeError(f"GET principal {name!r} returned unexpected response")
        return result

    def create_principal(self, principal: dict[str, Any]) -> None:
        self.request("POST", "/principal", principal)

    def patch_principal(self, name: str, patch: list[dict[str, Any]]) -> None:
        self.request("PATCH", f"/principal/{urllib.parse.quote(name, safe='')}", patch)


def reconcile(client: StalwartClient, desired: list[dict[str, Any]]) -> None:
    for principal in desired:
        name = principal["name"]
        current = client.get_principal(name)
        if current is None:
            client.create_principal(principal)
            print(f"created principal {name}")
            continue
        patch = build_patch(current, principal)
        if patch:
            client.patch_principal(name, patch)
            print(f"updated principal {name}")
        else:
            print(f"principal {name} unchanged")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Reconcile declarative Stalwart principals")
    parser.add_argument("--api-url", required=True, help="Stalwart management API base URL")
    parser.add_argument("--admin-password-file", required=True, type=Path)
    parser.add_argument("--desired", required=True, type=Path)
    parser.add_argument("--username", default="admin")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        raw = json.loads(args.desired.read_text())
        if not isinstance(raw, list) or not all(isinstance(item, dict) for item in raw):
            raise ValueError("desired JSON must be a list of objects")
        desired = validate_desired(raw)
        password = args.admin_password_file.read_text().strip()
        if not password:
            raise ValueError("admin password file is empty")
        reconcile(StalwartClient(args.api_url, args.username, password), desired)
    except (OSError, ValueError, RuntimeError, json.JSONDecodeError) as error:
        print(f"stalwart-ensure-principals: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
