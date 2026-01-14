"""Database operations."""

import shutil
import subprocess
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

import click


@dataclass
class Database:
    name: str
    path: Path
    size: str
    updated: str


@dataclass
class Snapshot:
    source: str
    tag: str
    path: Path
    size: str
    created: str


def list_databases(root: Path) -> list[Database]:
    """List all live databases (non-frozen directories)."""
    databases = []
    for p in sorted(root.iterdir()):
        if not p.is_dir() or ".frozen." in p.name:
            continue
        databases.append(
            Database(
                name=p.name,
                path=p,
                size=_dir_size(p),
                updated=_mtime(p),
            )
        )
    return databases


def list_frozen(root: Path, filter_db: str | None = None) -> list[Snapshot]:
    """List frozen snapshots, optionally filtered by database name."""
    snapshots = []
    for p in sorted(root.iterdir()):
        if not p.is_dir() or ".frozen." not in p.name:
            continue
        parts = p.name.split(".frozen.", 1)
        if len(parts) != 2:
            continue
        source, tag = parts
        if filter_db and source != filter_db:
            continue
        snapshots.append(
            Snapshot(
                source=source,
                tag=tag,
                path=p,
                size=_dir_size(p),
                created=_mtime(p),
            )
        )
    return snapshots


def freeze(root: Path, database: str, tag: str) -> Path:
    """Create a reflink copy of a database."""
    src = root / database
    dst = root / f"{database}.frozen.{tag}"

    if not src.exists():
        raise click.ClickException(f"Database not found: {database}")
    if dst.exists():
        raise click.ClickException(f"Snapshot already exists: {dst.name}")

    # Use cp --reflink for CoW copy (XFS/Btrfs)
    subprocess.run(
        ["cp", "--reflink=auto", "-a", str(src), str(dst)],
        check=True,
    )
    return dst


def thaw(root: Path, database: str, tag: str) -> None:
    """Remove a frozen snapshot."""
    path = root / f"{database}.frozen.{tag}"
    if not path.exists():
        raise click.ClickException(f"Snapshot not found: {path.name}")
    shutil.rmtree(path)


def sync(root: Path, database: str, url: str, method: str) -> None:
    """Sync database from remote URL."""
    dst = root / database
    dst.mkdir(parents=True, exist_ok=True)

    if method == "rsync":
        subprocess.run(
            ["rsync", "-avz", "--progress", url, str(dst) + "/"],
            check=True,
        )
    elif method == "rclone":
        subprocess.run(
            ["rclone", "sync", url, str(dst), "--progress"],
            check=True,
        )
    elif method == "wget":
        subprocess.run(
            ["wget", "-N", "-P", str(dst), url],
            check=True,
        )


def _dir_size(path: Path) -> str:
    """Get human-readable directory size."""
    try:
        result = subprocess.run(
            ["du", "-sh", str(path)],
            capture_output=True,
            text=True,
        )
        return result.stdout.split()[0]
    except Exception:
        return "?"


def _mtime(path: Path) -> str:
    """Get modification time as date string."""
    try:
        ts = path.stat().st_mtime
        return datetime.fromtimestamp(ts).strftime("%Y-%m-%d")
    except Exception:
        return "?"
