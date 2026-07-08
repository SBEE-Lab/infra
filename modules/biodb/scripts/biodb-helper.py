#!/usr/bin/env python3
"""Small state/publish helper for biodb shell recipes."""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
from pathlib import Path


def env_path(name: str, default: str) -> Path:
    return Path(os.environ.get(name, default))


def data_root() -> Path:
    return env_path("BIODB_DATA_ROOT", "/data/databases")


def workspace_root() -> Path:
    return env_path("BIODB_WORKSPACE_ROOT", "/workspace/shared/databases")


def atomic_symlink(target: Path, link: Path) -> None:
    link.parent.mkdir(parents=True, exist_ok=True)
    tmp = link.with_name(f".{link.name}.tmp-{os.getpid()}")
    try:
        tmp.unlink()
    except FileNotFoundError:
        pass
    tmp.symlink_to(target)
    tmp.replace(link)


def command_publish(args: argparse.Namespace) -> int:
    final = Path(args.final).resolve()
    if not final.exists():
        print(f"final path does not exist: {final}", file=sys.stderr)
        return 1

    current = workspace_root() / "current" / args.alias
    previous = workspace_root() / "previous" / args.alias

    if current.is_symlink():
        old = Path(os.readlink(current))
        atomic_symlink(old, previous)

    atomic_symlink(final, current)
    return 0


def command_manifest_write(args: argparse.Namespace) -> int:
    manifest_dir = data_root() / "manifests" / args.db
    manifest_dir.mkdir(parents=True, exist_ok=True)
    manifest_path = manifest_dir / f"{args.version}.json"
    payload = {
        "db": args.db,
        "version": args.version,
        "path": args.path,
        "validation_status": args.validation_status,
        "written_at": int(time.time()),
    }
    tmp = manifest_path.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    tmp.replace(manifest_path)
    print(manifest_path)
    return 0


def command_status(args: argparse.Namespace) -> int:
    current = workspace_root() / "current" / args.db
    status = {
        "db": args.db,
        "current": os.readlink(current) if current.is_symlink() else None,
        "current_exists": current.exists(),
    }
    print(json.dumps(status, indent=2, sort_keys=True))
    return 0


def command_check(args: argparse.Namespace) -> int:
    current = workspace_root() / "current" / args.db
    if current.is_symlink() and current.exists():
        print(f"OK current {args.db}: {os.readlink(current)}")
        return 0
    if current.is_symlink():
        print(f"BROKEN current {args.db}: {os.readlink(current)}", file=sys.stderr)
        return 2
    print(f"MISSING current {args.db}", file=sys.stderr)
    return 2


def command_gc_plan(_args: argparse.Namespace) -> int:
    plan = {
        "mode": "dry-run",
        "data_root": str(data_root()),
        "workspace_root": str(workspace_root()),
        "candidates": [],
        "note": "GC planner skeleton: no paths selected for deletion.",
    }
    print(json.dumps(plan, indent=2, sort_keys=True))
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="biodb-helper")
    sub = parser.add_subparsers(required=True)

    publish = sub.add_parser("publish", help="Atomically update current/previous symlinks")
    publish.add_argument("alias")
    publish.add_argument("final")
    publish.set_defaults(func=command_publish)

    manifest = sub.add_parser("manifest-write", help="Write minimal manifest")
    manifest.add_argument("db")
    manifest.add_argument("version")
    manifest.add_argument("path")
    manifest.add_argument("--validation-status", default="passed")
    manifest.set_defaults(func=command_manifest_write)

    status = sub.add_parser("status", help="Show DB status as JSON")
    status.add_argument("db")
    status.set_defaults(func=command_status)

    check = sub.add_parser("check", help="Cheap current symlink check")
    check.add_argument("db")
    check.add_argument("--repair-symlink-only", action="store_true")
    check.set_defaults(func=command_check)

    gc_plan = sub.add_parser("gc-plan", help="Print dry-run GC plan")
    gc_plan.set_defaults(func=command_gc_plan)

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
