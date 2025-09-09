# SBEE Laboratory Infrastructure

NixOS-based infrastructure for bioinformatics research with 3-server setup optimized for GPU computation, development, and data management.

## Infrastructure Overview

### Server Roles

| Server  | Role              | Key Services                       | Hardware                                  |
| ------- | ----------------- | ---------------------------------- | ----------------------------------------- |
| **PSI** | GPU Computation   | CUDA workloads, Bioinformatics DBs | RTX A6000 48GB, 128GB RAM, 4TB NVMe       |
| **RHO** | Development/Build | Desktop, CI/CD, Nix Cache          | Ryzen 9600X, 32GB RAM, 2TB NVMe + 4TB HDD |
| **TAU** | Storage/Backup    | Git hosting, DNS, Backups          | Ryzen 9600X, 32GB RAM, 2TB NVMe + 4TB HDD |

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

## Documentation

For detailed setup, configuration, and usage instructions, see the [documentation](https://sbee-lab.github.io/infra).

## License

MIT License - see [LICENSE](LICENSE) file for details.
