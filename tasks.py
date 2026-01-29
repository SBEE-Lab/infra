#!/usr/bin/env python3

import json
import os
import random
import shlex
import string
import subprocess
from datetime import datetime
from pathlib import Path
from tempfile import TemporaryDirectory
from typing import Any, List

from deploykit import DeployGroup, DeployHost
from invoke.tasks import task

ROOT = Path(__file__).parent.resolve()
os.chdir(ROOT)


def get_hosts(hosts: str) -> List[DeployHost]:
    return [DeployHost(h, user="root") for h in hosts.split(",")]


@task
def deploy(_: Any, hosts: str) -> None:
    """
    Use inv deploy --hosts
    """
    g = DeployGroup(get_hosts(hosts))

    def deploy(h: DeployHost) -> None:
        command = "sudo nixos-rebuild"
        target = f"{h.host}"

        res = subprocess.run(
            ["nix", "flake", "metadata", "--json"],
            text=True,
            check=True,
            stdout=subprocess.PIPE,
        )
        data = json.loads(res.stdout)
        path = data["path"]

        send = (
            "nix flake archive"
            if any(
                (
                    n.get("locked", {}).get("type") == "path"
                    or n.get("locked", {}).get("url", "").startswith("file:")
                )
                for n in data["locks"]["nodes"].values()
            )
            else f"nix copy {path}"
        )

        h.run_local(f"{send} --to ssh://{target}")

        hostname = h.host
        h.run(f"{command} switch --option accept-flake-config true --flake {path}#{hostname}")

    g.run_function(deploy)


@task
def update_sops_files(c: Any) -> None:
    """
    Update all sops yaml files according to .sops.nix rules
    """
    c.run(f"nix eval --json -f {ROOT}/.sops.nix | yq e -P - > {ROOT}/.sops.yaml")

    excludes = ["**/minio/secrets.yaml"]
    exclude_args = " ".join([f'--exclude "{e}"' for e in excludes])
    cmd = f"fd -e yaml {exclude_args} -x sops updatekeys --yes {{}}"

    result = c.run(cmd, hide=True, warn=True)

    lines = result.stdout.splitlines()
    updated_files = []

    for i, line in enumerate(lines):
        if "Syncing keys for file" in line:
            if i + 1 >= len(lines) or "already up to date" not in lines[i + 1]:
                filename = line.split("file ")[-1]
                updated_files.append(filename)
                print(f"✓ Updated: {filename}")

    if not updated_files:
        print("✓ All files already up to date")
    else:
        print(f"\n📝 Total: {len(updated_files)} files updated")


@task
def docs(c: Any) -> None:
    """
    Serve docs (mkdoc serve)
    """
    c.run("nix develop .#mkdocs -c mkdocs serve")


@task
def docs_linkcheck(c: Any) -> None:
    """
    Run docs online linkchecker
    """
    c.run("nix run .#docs-linkcheck.online")


def decrypt_host_key(flake_attr: str, tmpdir: str) -> None:
    def opener(path: str, flags: int) -> int:
        return os.open(path, flags, 0o400)

    t = Path(tmpdir)
    t.mkdir(parents=True, exist_ok=True)
    t.chmod(0o755)

    def decrypt(path: str, secret: str) -> None:
        file = t / path
        file.parent.mkdir(parents=True, exist_ok=True)
        with open(file, "w", opener=opener) as fh:
            subprocess.run(
                [
                    "sops",
                    "--extract",
                    secret,
                    "--decrypt",
                    f"{ROOT}/secrets.yaml",
                ],
                check=True,
                stdout=fh,
            )

    decrypt(
        "var/lib/ssh_secrets/ssh_host_ed25519_key",
        f'["ssh_host_ed25519_key"]["{flake_attr}"]',
    )
    decrypt("var/lib/ssh_secrets/initrd_host_ed25519_key", '["initrd_host_ed25519_key"]')


@task
def install(c: Any, machine: str, hostname: str, extra_args: str = "") -> None:
    """
    format disks and install nixos, i.e.: inv install --machine rho --hostname root@rho.sbee.lab
    """
    ask = input(f"Are you sure you want to install .#{machine} on {hostname}? [y/N] ")
    if ask != "y":
        return

    with TemporaryDirectory() as tmpdir:
        decrypt_host_keys(c, machine, tmpdir)
        c.run(
            "nix run github:nix-community/nixos-anywhere#nixos-anywhere -- "
            f"--flake .#{machine} "
            f"--kexec https://github.com/sbee-lab/infra/releases/download/v1.0.0/nixos-kexec.tar.gz "
            f"--post-kexec-ssh-port 10022 "
            "--build-on remote "
            f"--extra-files {tmpdir} "
            f"{extra_args} "
            f"root@{hostname}",
            echo=True,
        )


@task
def cleanup_gcroots(_: Any, hosts: str) -> None:
    g = DeployGroup(get_hosts(hosts))
    g.run("sudo find /nix/var/nix/gcroots/auto -type l -delete")


@task
def generate_password(c: Any, user: str = "root") -> None:
    """
    Generate password hashes for users i.e. for root in ./hosts/$HOSTNAME.yaml
    """
    passw = c.run(
        "nix shell --inputs-from . nixpkgs#xkcdpass -c xkcdpass --numwords 3 --delimiter - --count 1",
        echo=True,
    ).stdout
    out = c.run(f"echo '{passw}' | mkpasswd -m sha-512 -s", echo=True)
    print("# Add the following secrets")
    print(f"{user}-password: {passw}")
    print(f"{user}-password-hash: {out.stdout}")


@task
def generate_ssh_cert(c: Any, host: str) -> None:
    """
    Generate ssh cert for host, i.e. inv generate-ssh-cert bill
    """
    h = host
    sops_file = f"{ROOT}/hosts/{host}.yaml"
    with TemporaryDirectory() as tmpdir:
        # should we use ssh-keygen -A (Generate host keys of all default key types) here?
        c.run(f"mkdir -p {tmpdir}/etc/ssh")

        keytype = "ed25519"
        print("ssh cert extraction")
        res = c.run(
            f"sops --extract '[\"ssh_host_{keytype}_key.pub\"]' -d {sops_file}",
            warn=True,
        )
        privkey = Path(f"{tmpdir}/etc/ssh/ssh_host_{keytype}_key")
        pubkey = Path(f"{tmpdir}/etc/ssh/ssh_host_{keytype}_key.pub")
        if len(res.stdout) == 0:
            # create host key with comment -c and empty passphrase -N ''
            c.run(f"ssh-keygen -f {privkey} -t {keytype} -C 'host key for host {host}' -N ''")
            c.run(
                f"sops --set '[\"ssh_host_{keytype}_key\"] {json.dumps(privkey.read_text())}' {sops_file}"
            )
            c.run(
                f"sops --set '[\"ssh_host_{keytype}_key.pub\"] {json.dumps(pubkey.read_text())}' {sops_file}"
            )
        else:
            # save existing cert so we can generate an ssh certificate
            pubkey.write_text(res.stdout)

        os.umask(0o077)
        c.run(
            f"sops --extract '[\"ssh-ca\"]' -d {ROOT}/modules/sshd/ca-keys.yaml > {tmpdir}/ssh-ca"
        )
        valid_hostnames = f"{h},{h}.r,{h}.l"
        pubkey_path = f"{tmpdir}/etc/ssh/ssh_host_ed25519_key.pub"
        c.run(f"ssh-keygen -h -s {tmpdir}/ssh-ca -n {valid_hostnames} -I {h} {pubkey_path}")
        signed_key_src = f"{tmpdir}/etc/ssh/ssh_host_ed25519_key-cert.pub"
        signed_key_dst = f"{ROOT}/modules/sshd/certs/{host}-cert.pub"
        c.run(f"mv {signed_key_src} {signed_key_dst}")


@task
def print_age_key(_: Any, host: str) -> None:
    """
    Scans for the host key via ssh an converts it to age, i.e. inv scan-age-keys --host <hostname>
    """
    import subprocess

    proc = subprocess.run(
        [
            "sops",
            "--extract",
            '["ssh_host_ed25519_key.pub"]',
            "-d",
            f"{ROOT}/hosts/{host}.yaml",
        ],
        text=True,
        stdout=subprocess.PIPE,
        check=True,
    )
    print("###### Age key ######")
    subprocess.run(
        ["nix", "run", "--inputs-from", ".#", "nixpkgs#ssh-to-age"],
        input=proc.stdout,
        check=True,
        text=True,
    )


@task
def generate_wireguard_key(c: Any, hostname: str) -> None:
    """
    Generate wireguard private key for a given hostname (wg-admin)
    """
    with TemporaryDirectory() as tmp:
        c.run(
            f"nix shell --inputs-from . nixpkgs#wireguard-tools -c sh -c '"
            f"umask 077 && "
            f"wg genkey > {tmp}/private && "
            f"wg pubkey < {tmp}/private > {tmp}/public"
            f"'",
            echo=True,
        )

        wg_key = (Path(tmp) / "private").read_text().strip()
        wg_pubkey = (Path(tmp) / "public").read_text().strip()

        c.run(f"sops --set '[\"wg-admin-key\"] {json.dumps(wg_key)}' {ROOT}/hosts/{hostname}.yaml")
        c.run(f"echo {wg_pubkey} > {ROOT}/modules/wireguard/keys/{hostname}_wg-admin")


@task
def install_ssh_hostkeys(c: Any, machine: str, hostname: str) -> None:
    """
    Install ssh host keys stored in sops files on a remote host, i.e. inv install-ssh-hostkeys --machine rho --hostname rho
    """
    with TemporaryDirectory() as tmpdir:
        decrypt_host_keys(c, machine, tmpdir)
        c.run("mkdir -p /etc/ssh", pty=True)
        host = DeployHost(hostname, user="root")
        cmds = []
        for keyname in Path(f"{tmpdir}/etc/ssh").iterdir():
            cmds.append(f"echo '{keyname.read_text()}' > /etc/ssh/{keyname.name}")
        host.run(";".join(cmds))


def decrypt_host_keys(c: Any, host: str, tmpdir: str) -> None:
    os.mkdir(f"{tmpdir}/etc")
    os.mkdir(f"{tmpdir}/etc/ssh")
    for keyname in [
        "ssh_host_ed25519_key",
        "ssh_host_ed25519_key.pub",
    ]:
        if keyname.endswith(".pub"):
            os.umask(0o133)
        else:
            os.umask(0o177)
        c.run(
            f"sops --extract '[\"{keyname}\"]' -d {ROOT}/hosts/{host}.yaml > {tmpdir}/etc/ssh/{keyname}"
        )


@task
def wake(c: Any, host: str) -> None:
    """
    Wake up a remote host using Wake-on-LAN, i.e, inv wake --host rho
    """
    print(f"Waking up {host}...")
    print(f"Getting MAC address for {host}...")

    try:
        mac_result = c.run(
            f"nix eval {ROOT}#nixosConfigurations.{host}.config.networking.sbee.currentHost.mac --raw",
            hide=True,
        )

        mac_address = mac_result.stdout.strip()

        if not mac_address or mac_address == "null":
            print(f"Error: No MAC address configured for {host}")
            print(f"Please add MAC address to hosts/{host}.nix for wake-on-lan")
            return

        print(f"MAC address: {mac_address}")
        print("Sending Wake-on-LAN magic packet...")

        c.run(f"nix run nixpkgs#wakeonlan -- {mac_address}", echo=True)
        print(f"Magic packet sent to {host}!")

    except Exception as e:
        print(f"Error: {e}")
        if "nixosConfigurations" in str(e):
            print(f"Make sure {host} is defined in your flake configuration")


@task
def shutdown(c: Any, host: str) -> None:
    """
    Shutdown a remote host, i.e. inv shutdown --host rho
    """
    print(f"Shutdown {host}...")
    c.run(f"ssh root@{host} shutdown now")


@task
def reboot(c: Any, host: str) -> None:
    """
    reboot a remote host, i.e. inv reboot --host rho
    """
    print(f"Reboot {host}...")
    c.run(f"ssh root@{host} reboot now")


@task
def start_service(c: Any, host: str, service: str) -> None:
    """
    Start a service on a remote host, i.e. inv start-service --host rho --service nginx
    """
    print(f"Starting service '{service}' on {host}...")
    c.run(f"ssh root@{host} systemctl start {service}", echo=True)
    print(f"Service '{service}' started on {host}")


@task
def stop_service(c: Any, host: str, service: str) -> None:
    """
    Stop a service on a remote host, i.e. inv stop-service --host rho --service nginx
    """
    print(f"Stopping service '{service}' on {host}...")
    c.run(f"ssh root@{host} systemctl stop {service}", echo=True)
    print(f"Service '{service}' stopped on {host}")


@task
def restart_service(c: Any, host: str, service: str) -> None:
    """
    Restart a service on a remote host, i.e. inv restart-service --host rho --service nginx
    """
    print(f"Restarting service '{service}' on {host}...")
    c.run(f"ssh root@{host} systemctl restart {service}", echo=True)
    print(f"Service '{service}' restarted on {host}")


@task
def enable_service(c: Any, host: str, service: str) -> None:
    """
    Enable a service to start automatically on a remote host, i.e. inv enable-service --host rho --service nginx
    """
    print(f"Enabling service '{service}' on {host}...")
    c.run(f"ssh root@{host} systemctl enable {service}", echo=True)
    print(f"Service '{service}' enabled on {host}")


@task
def disable_service(c: Any, host: str, service: str) -> None:
    """
    Disable a service from starting automatically on a remote host, i.e. inv disable-service --host rho --service nginx
    """
    print(f"Disabling service '{service}' on {host}...")
    c.run(f"ssh root@{host} systemctl disable {service}", echo=True)
    print(f"Service '{service}' disabled on {host}")


@task
def reload_service(c: Any, host: str, service: str) -> None:
    """
    Reload a service configuration on a remote host, i.e. inv reload-service --host rho --service nginx
    """
    print(f"Reloading service '{service}' configuration on {host}...")
    c.run(f"ssh root@{host} systemctl reload {service}", echo=True)
    print(f"Service '{service}' configuration reloaded on {host}")


@task
def list_services(c: Any, host: str, pattern: str = "") -> None:
    """
    List services on a remote host, i.e. inv list-services --host rho --pattern nginx
    """
    print(f"Listing services on {host}...")
    if pattern:
        c.run(f"ssh root@{host} systemctl list-units --type=service | grep {pattern}", echo=True)
    else:
        c.run(f"ssh root@{host} systemctl list-units --type=service", echo=True)


@task
def add_server(c: Any, hostname: str, skip_attic: bool = False) -> None:
    """
    Generate new server keys and configurations for a given hostname and hardware config.
    Use --skip-attic if attic server is not yet available.
    """

    print(f"Adding {hostname}")

    keys = None
    with open(f"{ROOT}/pubkeys.json", "r") as f:
        keys = f.read()
    keys = json.loads(keys)
    if keys["machines"].get(hostname, None):
        print("Configuration already exists")
        exit(-1)
    keys["machines"][hostname] = ""
    with open(f"{ROOT}/pubkeys.json", "w") as f:
        json.dump(keys, f, indent=2)

    update_sops_files(c)

    sops_file = f"{ROOT}/hosts/{hostname}.yaml"

    print("Generating Password")
    size = 12
    chars = string.ascii_letters + string.digits
    passwd = "".join(random.choice(chars) for _ in range(size))
    passwd_hash = subprocess.check_output(
        ["mkpasswd", "-m", "sha-512", "-s"], input=passwd, text=True
    )
    with open(sops_file, "w") as hosts:
        hosts.write(f"root-password: {passwd}\n")
        hosts.write(f"root-password-hash: {passwd_hash}")
    enc_out = subprocess.check_output(["sops", "-e", f"{sops_file}"], text=True)
    with open(sops_file, "w") as hosts:
        hosts.write(enc_out)

    print("Generating SSH certificate")
    generate_ssh_cert(c, hostname)

    print("Generating Wireguard key")
    generate_wireguard_key(c, hostname)

    if not skip_attic:
        print("Generating Attic token (pull only)")
        try:
            token = generate_attic_token_for_host(c, hostname, push=False, pull=True)
            c.run(
                f"sops --set '[\"attic-token\"] {json.dumps(token)}' {sops_file}",
            )
            print("✓ Attic token added (pull)")
            print(
                f"  Note: Run 'inv generate-attic-host-token --hostname {hostname} --push' if push access needed"
            )
        except Exception as e:
            print(f"⚠ Attic token generation failed: {e}")
            print(f"  Run 'inv generate-attic-host-token --hostname {hostname}' later")
    else:
        print("Skipping Attic token generation (--skip-attic)")

    print("Generating age key")
    key_ed = subprocess.Popen(
        ["sops", "--extract", '["ssh_host_ed25519_key.pub"]', "-d", sops_file],
        stdout=subprocess.PIPE,
    )

    age = subprocess.check_output(
        ["nix", "run", "--inputs-from", ".#", "nixpkgs#ssh-to-age"],
        text=True,
        stdin=key_ed.stdout,
    )
    age = age.rstrip()

    print("Updating pubkeys.json")
    keys = None
    with open(f"{ROOT}/pubkeys.json", "r") as f:
        keys = json.load(f)
    keys["machines"][hostname] = age
    with open(f"{ROOT}/pubkeys.json", "w") as f:
        json.dump(keys, f, indent=2)

    print("Updating sops files")
    update_sops_files(c)

    example_host_config = f"""
{{
  imports = [
    ../modules/hardware/placeholder.nix
  ];

  networking.hostName = "{hostname}";

  system.stateVersion = "25.05";
}}"""
    print(f"Writing example hosts/{hostname}.nix")
    with open(f"{ROOT}/hosts/{hostname}.nix", "w") as f:
        f.write(example_host_config)

    c.run(
        "git add "
        + f"{ROOT}/hosts/{hostname}.nix "
        + f"{ROOT}/hosts/{hostname}.yaml "
        + f"{ROOT}/pubkeys.json "
        + f"{ROOT}/.sops.yaml "
        + f"{ROOT}/modules/sshd/certs/{hostname}-cert.pub"
    )


@task
def build_all(_: Any, builder: str = "", concurrent: int = 12, arch: str = "x86_64-linux") -> None:
    """
    Build all flake closure on builder
    e.g., inv build-all --builder psi --concurrent 24
    """
    cmd = [
        "nix",
        "run",
        "github:Mic92/nix-fast-build",
        "--",
        "--flake",
        f"{ROOT}#checks.{arch}",
    ]

    if builder:
        cmd.extend(["--remote", f"root@{builder}"])
        print(f"Building on remote host: {builder}")
    else:
        print("Building locally")

    if concurrent:
        cmd.extend(["--max-jobs", str(concurrent)])

    print(f"Building with {concurrent} concurrent jobs...")
    print(f"Architecture: {arch}")

    try:
        subprocess.run(
            cmd,
            text=True,
            check=True,
        )
        print("✓ Build completed successfully")
    except subprocess.CalledProcessError as e:
        print(f"✗ Build failed with exit code {e.returncode}")
        raise


def check_expired_accounts():
    """
    Check for expired student accounts and return the data
    """
    import re

    students_file = ROOT / "modules" / "users" / "students.nix"

    # Parse the students.nix file for expires lines
    with open(students_file, "r") as f:
        content = f.read()

    # Find all user blocks with expires field
    # Pattern to match user = { ... expires = "YYYY-MM-DD"; ... }
    user_pattern = r'(\w+)\s*=\s*\{[^}]*expires\s*=\s*"(\d{4}-\d{2}-\d{2})"[^}]*\}'

    expired = []
    expiring = []
    today = datetime.now().date()

    # Find all matches
    for match in re.finditer(user_pattern, content, re.DOTALL):
        username = match.group(1)
        expires_str = match.group(2)
        expires_date = datetime.strptime(expires_str, "%Y-%m-%d").date()

        # Skip if this is inside a comment
        # Check if the line with expires is commented
        expires_line_start = match.start(2)
        line_start = content.rfind("\n", 0, expires_line_start) + 1
        line = content[line_start:expires_line_start]
        if "#" in line:
            continue

        days_until_expiry = (expires_date - today).days

        if days_until_expiry < 0:
            expired.append((username, expires_str, -days_until_expiry))
        elif days_until_expiry <= 30:
            expiring.append((username, expires_str, days_until_expiry))

    # Sort by expiration date
    expired.sort(key=lambda x: x[1])
    expiring.sort(key=lambda x: x[2])

    return {"expired": expired, "expiring": expiring, "today": today.isoformat()}


@task
def expired_accounts(_: Any) -> None:
    """
    Check for expired student accounts (human-readable output)
    """
    data = check_expired_accounts()
    expired = data["expired"]
    expiring = data["expiring"]
    today = data["today"]

    if expired:
        print(f"\n❌ Expired student accounts (as of {today}):")
        print("-" * 60)
        for username, expires, days_ago in expired:
            print(f"  {username:<20} Expired: {expires} ({days_ago} days ago)")
        print(f"\nTotal expired accounts: {len(expired)}")
        print("\nAction required: Move these users to deletedUsers in modules/users/default.nix")
    else:
        print("\n✅ No expired student accounts found.")

    if expiring:
        print("\n⚠️  Student accounts expiring within 30 days:")
        print("-" * 60)
        for username, expires, days_left in expiring:
            print(f"  {username:<20} Expires: {expires} ({days_left} days)")

    # Summary
    print("\n📊 Summary:")
    print(f"  Expired: {len(expired)}")
    print(f"  Expiring soon: {len(expiring)}")
    print(f"  Total accounts checked: {len(expired) + len(expiring)}")


@task
def expired_accounts_json(_: Any) -> None:
    """
    Check for expired student accounts (JSON output for automation)
    """
    data = check_expired_accounts()

    # Convert to JSON-friendly format - only include what GitHub action needs
    result = {
        "expired": [
            {"username": username, "expiration_date": expires}
            for username, expires, _ in data["expired"]
        ],
        "expired_count": len(data["expired"]),
    }

    print(json.dumps(result, indent=2))


# =============================================================================
# Attic Cache Management
# =============================================================================

ATTIC_HOST = "eta"
ATTIC_INFRA_CACHE = "infra"  # Private cache for infra hosts


@task
def attic_make_token(
    c: Any,
    sub: str,
    validity: str = "1y",
    caches: str = "main",
    push: bool = True,
    pull: bool = True,
    create_cache: bool = False,
    configure_cache: bool = False,
    delete: bool = False,
) -> None:
    """
    Create an attic token on the cache server.
    e.g., inv attic-make-token --sub ci --validity 1y --caches main
          inv attic-make-token --sub admin --validity 10y --caches "*" --create-cache --configure-cache --delete
    """
    cmd_parts = [
        "atticd-atticadm",
        "make-token",
        f"--sub {shlex.quote(sub)}",
        f"--validity {shlex.quote(validity)}",
    ]

    cache_list = caches.split(",")
    for cache in cache_list:
        cache = cache.strip()
        if pull:
            cmd_parts.append(f"--pull {shlex.quote(cache)}")
        if push:
            cmd_parts.append(f"--push {shlex.quote(cache)}")
        if delete:
            cmd_parts.append(f"--delete {shlex.quote(cache)}")
        if create_cache:
            cmd_parts.append(f"--create-cache {shlex.quote(cache)}")
        if configure_cache:
            cmd_parts.append(f"--configure-cache {shlex.quote(cache)}")
            cmd_parts.append(f"--configure-cache-retention {shlex.quote(cache)}")

    cmd = " ".join(cmd_parts)
    print(f"Creating token for '{sub}' with access to: {caches}")
    c.run(f"ssh root@{ATTIC_HOST} {shlex.quote(cmd)}", echo=True)


@task
def attic_gc(c: Any) -> None:
    """
    Trigger garbage collection on the attic server.
    """
    print(f"Triggering GC on {ATTIC_HOST}...")
    c.run(f"ssh root@{ATTIC_HOST} 'atticd --mode garbage-collector-once'", echo=True)
    print("✓ Garbage collection completed")


def generate_attic_token_for_host(
    c: Any,
    hostname: str,
    push: bool = False,
    pull: bool = True,
    validity: str = "10y",
) -> str:
    """
    Generate an attic token for a host to access the infra cache.
    Returns the token string.
    """
    cmd_parts = [
        "atticd-atticadm make-token",
        f"--sub {shlex.quote(hostname)}",
        f"--validity {shlex.quote(validity)}",
    ]
    if pull:
        cmd_parts.append(f"--pull {shlex.quote(ATTIC_INFRA_CACHE)}")
    if push:
        cmd_parts.append(f"--push {shlex.quote(ATTIC_INFRA_CACHE)}")

    cmd = " ".join(cmd_parts)
    result = c.run(f"ssh root@{ATTIC_HOST} {shlex.quote(cmd)}", hide=True)
    token = result.stdout.strip()
    return token


@task
def generate_attic_host_token(
    c: Any,
    hostname: str,
    push: bool = False,
    pull: bool = True,
    validity: str = "10y",
    sops_file: str = "",
    secret_name: str = "attic-token",
) -> None:
    """
    Generate attic token for a host and add it to sops secrets.
    e.g., inv generate-attic-host-token --hostname rho              # pull only
          inv generate-attic-host-token --hostname psi --push       # push + pull
          inv generate-attic-host-token --hostname buildbot --push --sops-file modules/buildbot/secrets.yaml --secret-name attic-auth-token
    """
    if not sops_file:
        sops_file = f"{ROOT}/hosts/{hostname}.yaml"

    perms = []
    if pull:
        perms.append("pull")
    if push:
        perms.append("push")
    print(f"Generating attic token for '{hostname}' with permissions: {', '.join(perms)}")

    token = generate_attic_token_for_host(c, hostname, push=push, pull=pull, validity=validity)

    if not Path(sops_file).exists():
        print(f"Error: {sops_file} does not exist")
        return

    print(f"Adding token to {sops_file} as '{secret_name}'...")
    c.run(
        f"sops --set '[\"{secret_name}\"] {json.dumps(token)}' {sops_file}",
        echo=True,
    )
    print(f"✓ Attic token added for '{hostname}'")


@task
def expired_accounts_create_issues(c: Any) -> None:
    """
    Create GitHub issues for expired student accounts
    """
    data = check_expired_accounts()
    expired = data["expired"]

    if not expired:
        print("No expired accounts found.")
        return

    print(f"Found {len(expired)} expired accounts")

    for username, expires, days_ago in expired:
        print(f"\nProcessing expired account: {username}")

        # Check if an issue already exists
        result = c.run(
            f'gh issue list --search "Expired student account: {username}" --state all --json number --jq ".[0].number"',
            hide=True,
            warn=True,
        )

        if result.ok and result.stdout.strip():
            issue_number = result.stdout.strip()
            print(f"  Issue already exists: #{issue_number}")
            continue

        print(f"  Creating issue for {username}")

        # Create the issue body
        issue_body = f"""## Expired Student Account

**Username:** {username}
**Expiration Date:** {expires}
**Days Expired:** {days_ago}

This student account has expired and should be reviewed for removal.

### Action Items
- [ ] Verify the student has completed their work
- [ ] Back up any important data if needed
- [ ] Move the user to `deletedUsers` in `modules/users/default.nix`
- [ ] Remove SSH keys and any special access permissions
- [ ] Deploy changes to affected systems

### How to remove the user
1. Edit `modules/users/students.nix`
2. Remove the user definition
3. Add the username to `users.deletedUsers` in `modules/users/default.nix`
4. Commit and create a PR

cc @SBEE-Lab/infra-admins"""

        # Create the issue
        c.run(
            f"gh issue create "
            f'--title "Expired student account: {username}" '
            f"--body {shlex.quote(issue_body)} ",
            "--label 'expired-user' ",
            echo=True,
        )
