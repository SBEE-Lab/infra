#!/usr/bin/env python3

import argparse
import json
import re
import subprocess
from pathlib import Path
from typing import Any


def node_id(prefix: str, value: str) -> str:
    return f"{prefix}_{re.sub(r'[^A-Za-z0-9_]', '_', value)}"


def host_label(name: str, host: dict[str, Any]) -> str:
    lines = [name, host["ipv4"]]
    endpoint = host.get("wireguardEndpoint")
    if endpoint:
        lines.append(f"WG endpoint {endpoint}")
    return "<br/>".join(lines)


def render_underlay(hosts: dict[str, dict[str, Any]]) -> list[str]:
    lines = ["```mermaid", "flowchart TB", '  internet["인터넷"]']
    groups: dict[str, tuple[str, list[tuple[str, dict[str, Any]]]]] = {
        "vps": ("VPS 네트워크", []),
        "kren": ("KREN 네트워크 · NAT", []),
        "lab": ("연구실 네트워크 · NAT", []),
        "other": ("기타 네트워크", []),
    }

    for name, host in sorted(hosts.items()):
        tags = set(host.get("tags", []))
        if "vps-network" in tags:
            group = "vps"
        elif "lab-network" in tags:
            group = "lab"
        elif "kren-dns" in tags:
            group = "kren"
        else:
            group = "other"
        groups[group][1].append((name, host))

    for group, (title, members) in groups.items():
        if not members:
            continue
        lines.append(f'  subgraph {group}["{title}"]')
        gateways = sorted(
            {host["gateway"] for _, host in members if isinstance(host.get("gateway"), str)}
        )
        gateway_id = f"{group}_gateway"
        if len(gateways) == 1 and group != "vps":
            gateway_label = "연구실 게이트웨이" if group == "lab" else "게이트웨이"
            lines.append(f'    {gateway_id}["{gateway_label}<br/>{gateways[0]}"]')
        for name, host in members:
            lines.append(f'    {name}_under["{host_label(name, host)}"]')
            if len(gateways) == 1 and group != "vps":
                lines.append(f"    {gateway_id} --> {name}_under")
        lines.append("  end")

        if group == "vps":
            for name, host in members:
                if "public-ip" in host.get("tags", []):
                    lines.append(f"  internet --> {name}_under")
        elif len(gateways) == 1:
            lines.append(f'  internet -. "NAT" .-> {gateway_id}')

    lines.extend(["```", ""])
    return lines


def render_wireguard(
    hosts: dict[str, dict[str, Any]], wireguard: dict[str, dict[str, Any]]
) -> list[str]:
    lines = ["```mermaid", "graph LR"]
    ip_to_host = {
        host["wg-admin"]: name for name, host in hosts.items() if host.get("wg-admin") is not None
    }

    for name, host in sorted(hosts.items()):
        address = host.get("wg-admin")
        if address:
            lines.append(f'  wg_{name}["{name}<br/>{address}"]')

    edges: set[tuple[str, str]] = set()
    external_ips: set[str] = set()
    for source, interfaces in sorted(wireguard.items()):
        for interface in interfaces.values():
            for peer in interface.get("peers", []):
                for allowed in peer.get("AllowedIPs", []):
                    target_ip = allowed.split("/", maxsplit=1)[0]
                    target = ip_to_host.get(target_ip)
                    if target is None:
                        external_ips.add(target_ip)
                        target_node = node_id("external", target_ip)
                    else:
                        target_node = target
                    if source == target_node:
                        continue
                    left, right = sorted((source, target_node))
                    edges.add((left, right))

    for address in sorted(external_ips):
        identifier = node_id("external", address)
        lines.append(f'  wg_{identifier}["외부 peer<br/>{address}"]')
    for source, target in sorted(edges):
        lines.append(f"  wg_{source} --- wg_{target}")

    lines.extend(["```", ""])
    return lines


def render_table(hosts: dict[str, dict[str, Any]]) -> list[str]:
    lines = [
        "| 호스트 | 물리 IPv4 | 게이트웨이 | wg-admin | WireGuard endpoint | 태그 |",
        "|--------|-----------|------------|----------|--------------------|------|",
    ]
    for name, host in sorted(hosts.items()):
        tags = ", ".join(f"`{tag}`" for tag in host.get("tags", []))
        lines.append(
            f"| {name} | {host['ipv4']} | {host.get('gateway') or '—'} | "
            f"{host.get('wg-admin') or '—'} | {host.get('wireguardEndpoint') or '—'} | {tags} |"
        )
    lines.append("")
    return lines


def render_topology(data: dict[str, Any]) -> str:
    hosts = data["hosts"]
    wireguard = data["wireguard"]
    lines = [
        "# 논리 네트워크 토폴로지",
        "",
        "> `inv update-network-topology`으로 NixOS host inventory와 WireGuard peer 설정에서 자동 생성합니다.",
        "",
        "## Underlay",
        "",
    ]
    lines.extend(render_underlay(hosts))
    lines.extend(["## wg-admin overlay", ""])
    lines.extend(render_wireguard(hosts, wireguard))
    lines.extend(["## 평가된 host inventory", ""])
    lines.extend(render_table(hosts))
    return "\n".join(lines)


def nix_eval(root: Path, attribute: str) -> Any:
    result = subprocess.run(
        ["nix", "eval", "--json", attribute],
        cwd=root,
        check=True,
        text=True,
        stdout=subprocess.PIPE,
    )
    return json.loads(result.stdout)


def load_data(root: Path) -> dict[str, Any]:
    hostnames = sorted(path.stem for path in (root / "hosts").glob("*.nix"))
    if not hostnames:
        raise RuntimeError("host inventory is empty")
    hosts = nix_eval(
        root,
        f".#nixosConfigurations.{hostnames[0]}.config.networking.sbee.hosts",
    )
    wireguard = {
        host: nix_eval(
            root,
            f".#nixosConfigurations.{host}.config.networking.sbee.wireguard",
        )
        for host in hostnames
    }
    return {"hosts": hosts, "wireguard": wireguard}


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate logical network topology Markdown")
    parser.add_argument("--data", type=Path, help="Use evaluated inventory JSON instead of Nix")
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    if args.data:
        data = json.loads(args.data.read_text(encoding="utf-8"))
    else:
        data = load_data(root)
    print(render_topology(data), end="")


if __name__ == "__main__":
    main()
