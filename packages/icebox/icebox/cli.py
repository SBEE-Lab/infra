"""CLI interface for icebox."""

from pathlib import Path

import click

from . import db


@click.group()
@click.option(
    "--root",
    type=click.Path(exists=True, path_type=Path),
    default="/workspace/shared/databases",
    envvar="ICEBOX_ROOT",
    help="Database root directory",
)
@click.pass_context
def main(ctx: click.Context, root: Path) -> None:
    """Keep databases fresh, freeze when needed."""
    ctx.ensure_object(dict)
    ctx.obj["root"] = root


@main.command("list")
@click.option("--frozen", is_flag=True, help="List frozen snapshots only")
@click.argument("database", required=False)
@click.pass_context
def list_cmd(ctx: click.Context, frozen: bool, database: str | None) -> None:
    """List databases or frozen snapshots."""
    root = ctx.obj["root"]

    if frozen:
        snapshots = db.list_frozen(root, database)
        if not snapshots:
            click.echo("No frozen snapshots found.")
            return
        for s in snapshots:
            click.echo(f"{s.source}.frozen.{s.tag}\t{s.size}\t{s.created}")
    else:
        databases = db.list_databases(root)
        if not databases:
            click.echo("No databases found.")
            return
        for d in databases:
            click.echo(f"{d.name}\t{d.size}\t{d.updated}")


@main.command()
@click.argument("database")
@click.argument("tag")
@click.pass_context
def freeze(ctx: click.Context, database: str, tag: str) -> None:
    """Create a frozen snapshot of a database."""
    root = ctx.obj["root"]
    path = db.freeze(root, database, tag)
    click.echo(f"Frozen: {path}")


@main.command()
@click.argument("database")
@click.argument("tag")
@click.pass_context
def thaw(ctx: click.Context, database: str, tag: str) -> None:
    """Remove a frozen snapshot."""
    root = ctx.obj["root"]
    db.thaw(root, database, tag)
    click.echo(f"Thawed: {database}.frozen.{tag}")


@main.command()
@click.argument("database")
@click.argument("url")
@click.option("--method", type=click.Choice(["rsync", "rclone", "wget"]), default="rsync")
@click.pass_context
def sync(ctx: click.Context, database: str, url: str, method: str) -> None:
    """Sync database from remote source."""
    root = ctx.obj["root"]
    db.sync(root, database, url, method)
    click.echo(f"Synced: {database}")


if __name__ == "__main__":
    main()
