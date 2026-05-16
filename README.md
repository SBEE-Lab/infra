# SBEE Laboratory Infrastructure

NixOS-based infrastructure for bioinformatics research with 3-server setup optimized for GPU computation, development, and data management.

## Infrastructure Overview

### Server Roles

| Server  | Role                         | Key Services                                    | Hardware                                                                     |
| ------- | ---------------------------- | ----------------------------------------------- | ---------------------------------------------------------------------------- |
| **PSI** | GPU/CPU Research Computation | CUDA workloads, Bioinformatics DBs, Nix Builder | Ryzen Threadripper PRO 5965WX (24 Core), RTX A6000 48GB, 128GB RAM, 4TB NVMe |
| **RHO** | Storage/Build                | Cold Storage with Console (MinIO), CI/CD        | Ryzen 9600X (6 Core), 32GB RAM, 2TB NVMe + 4TB HDD                           |
| **TAU** | Storage/Backup               | Cold Storage (MinIO), Backups                   | Ryzen 9600X (6 Core), 32GB RAM, 2TB NVMe + 4TB HDD                           |
| **ETA** | VPS/Hosting                  | Gateway, Auth, ntfy, Upterm relay               | EPYC-Rome (2 Core), 4GB RAM, 100Gb NVMe, 5TB Bandwidth                        |

### User Groups

- **admin**: Full system administration access (e.g., infra manager, currently @mulatta)
- **researcher**: GPU access, bioinformatics tools, data analysis (e.g., graduates)
- **student**: Basi development environments (e.g., undergraduate)

## Quick Start

### Prerequisites

- NixOS 24.11+ with flakes enabled

### Deployment

```bash
# Clone the repository
git clone https://github.com/sbee-lab/infra
cd infra

# to enter devshell
nix develop

# or, if you use direnv
direnv allow
```

### Deployment

use `invoke`

```python
❯ inv -l
Available tasks:

  add-server                       Generate new server keys and configurations for a given hostname and hardware config
  cleanup-gcroots                  Remove automatic GC roots so stale closures can be collected by the next GC
  deploy                           Use inv deploy --hosts
  disable-service                  Disable a service from starting automatically on a remote host, i.e. inv disable-service --host rho --service nginx
  docs                             Build documentation with Nix and serve it locally
  docs-linkcheck                   Run documentation link checker
  enable-service                   Enable a service to start automatically on a remote host, i.e. inv enable-service --host rho --service nginx
  expired-accounts                 Check for expired student accounts (human-readable output)
  expired-accounts-create-issues   Create GitHub issues for expired student accounts
  expired-accounts-json            Check for expired student accounts (JSON output for automation)
  generate-admin-wireguard-key     Generate an admin WireGuard key and client config
  generate-password                Generate password hashes for users i.e. for root in ./hosts/$HOSTNAME.yaml
  generate-ssh-cert                Generate ssh cert for host, i.e. inv generate-ssh-cert bill
  generate-wireguard-key           Generate wireguard private key for a given hostname (wg-admin)
  install                          format disks and install nixos, i.e.: inv install --machine rho --hostname root@rho.sbee.lab
  install-ssh-hostkeys             Install ssh host keys stored in sops files on a remote host, i.e. inv install-ssh-hostkeys --machine rho --hostname rho
  list-services                    List services on a remote host, i.e. inv list-services --host rho --pattern nginx
  print-age-key                    Convert a host SSH public key from sops to an age recipient
  reboot                           reboot a remote host, i.e. inv reboot --host rho
  reload-service                   Reload a service configuration on a remote host, i.e. inv reload-service --host rho --service nginx
  restart-service                  Restart a service on a remote host, i.e. inv restart-service --host rho --service nginx
  shutdown                         Shutdown a remote host, i.e. inv shutdown --host rho
  start-service                    Start a service on a remote host, i.e. inv start-service --host rho --service nginx
  stop-service                     Stop a service on a remote host, i.e. inv stop-service --host rho --service nginx
  update-sops-files                Update all sops yaml files according to .sops.nix rules
  wake                             Wake up a remote host using Wake-on-LAN, i.e, inv wake --host rho

```

## Documentation

For detailed setup, configuration, and usage instructions, see the [documentation](https://sbee-lab.github.io/infra).

## License

MIT License - see [LICENSE](LICENSE) file for details.
