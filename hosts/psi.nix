{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.sbee.monitoring) mkSystemdJobSpec;

  biodbDatabases = {
    blast-nr.enable = true;
    blast-nt.enable = true;
    blast-swissprot.enable = true;
    uniref90.enable = true;
    uniref100.enable = true;
    pdb.enable = true;
    pdb-mmcif.enable = true;
    rnacentral.enable = true;
    pfam.enable = true;
    rfam.enable = true;
    # alphafold.enable = true;  # Very large, enable when needed
  };

in
{
  imports = [
    ../modules/nix-grpc-store.nix
    ../modules/disko/xfs-root.nix
    ../modules/disko/xfs-mdadm.nix
    ../modules/disko/xfs-project-quota.nix
    ../modules/nvidia.nix
    ../modules/tailscale
    ../modules/buildbot/database.nix
    ../modules/buildbot/master.nix
    ../modules/buildbot/reverse-proxy.nix
    ../modules/monitoring/vector
    ../modules/monitoring/exporters/systemd-status.nix
    ../modules/backup/psi-protected.nix
    ../modules/backup/postgresql.nix
    ../modules/niks3
    ../modules/multievolve
    # ../modules/vllm
    ../modules/biodb
    ../modules/biodb/databases.nix
    ../modules/docling
    ../modules/tei
  ];

  disko.rootDisk = "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_4TB_S7DPNU0Y404280K";

  disko.xfsMdadm = {
    enable = true;
    arrays = {
      # SSD RAID0 for workspace (16TB total)
      workspace = {
        disks.ssd1 = "/dev/disk/by-id/nvme-Samsung_SSD_9100_PRO_8TB_S7YHNJ0YA05025J";
        disks.ssd2 = "/dev/disk/by-id/nvme-Samsung_SSD_9100_PRO_8TB_S7YHNJ0YA02750H";
        mountpoint = "/workspace";
        extraXfsOptions = [
          "allocsize=16m"
        ];
      };
      # HDD RAID0 for data (60TB total)
      data = {
        disks.hdd1 = "/dev/disk/by-id/ata-ST30000NT011-3V2103_K1S0HG8X";
        disks.hdd2 = "/dev/disk/by-id/ata-ST30000NT011-3V2103_K1S0H1A7";
        mountpoint = "/data";
        extraXfsOptions = [
          "largeio"
          "allocsize=64m"
          "filestreams"
        ];
      };
    };
  };

  disko.xfsProjectQuotas = {
    enable = true;
    filesystems."/".projects.blobs = {
      id = 1001;
      path = "/blobs";
      blockHardLimit = "200g";
    };
  };

  # Enable periodic TRIM for SSD health
  services.fstrim.enable = true;

  networking.hostName = "psi";

  # Avoid repeating cold binary-cache misses between daily Nixbot builds.
  nix.settings.narinfo-cache-negative-ttl = 24 * 60 * 60;

  services.sbee.backups = {
    psiProtected.enable = true;
    postgresql = {
      enable = true;
      databases = [
        "niks3"
        "nixbot"
      ];
      startAt = "*-*-* 02:30:00";
    };
  };

  services.sbee.systemdStatusExporter = {
    enable = true;
    units = map (
      name:
      mkSystemdJobSpec {
        unit = "biodb-${name}.service";
        jobClass = "biodb";
        triggerKind = "manual";
        alertEnabled = false;
      }
    ) (builtins.attrNames biodbDatabases);
  };

  # Bioinformatics database sync management
  services.biodb = {
    enable = true;
    root = "/data/databases";

    # Enable databases needed for research
    databases = biodbDatabases;
  };

  services.tei = {
    enable = true;
    listenAddress = "::";
    openFirewall = false;
    models = {
      embed = {
        model = "Qwen/Qwen3-Embedding-0.6B";
        port = 8201;
        extraArgs = [
          "--pooling"
          "last-token"
          "--max-batch-tokens"
          "16384"
          "--max-concurrent-requests"
          "512"
        ];
      };
      rerank = {
        model = "BAAI/bge-reranker-v2-m3";
        port = 8202;
        extraArgs = [
          "--max-batch-tokens"
          "16384"
          "--max-concurrent-requests"
          "512"
        ];
      };
    };
  };

  services.prometheus.exporters.nvidia-gpu = {
    enable = true;
    listenAddress = config.networking.sbee.currentHost.wg-admin;
    port = 9835;
    extraFlags = [ "--no-shutdown-on-error" ];
  };

  networking.firewall = {
    interfaces."wg-admin".allowedTCPPorts = [
      8201 # TEI embed API and Prometheus metrics
      8202 # TEI rerank API and Prometheus metrics
      9835 # nvidia-gpu exporter
    ];
    extraCommands = ''
      iptables -A nixos-fw -i tinc.naru -s 10.208.0.6 -p tcp --dport 8201 -j nixos-fw-accept
      ip6tables -A nixos-fw -i tinc.naru -s fdec:ca5f:90ad:b0c7:d0dc:cc85:1781:f55e -p tcp --dport 8201 -j nixos-fw-accept
    '';
  };

  programs.singularity = {
    enable = true;
    package = pkgs.apptainer;
  };

  system.stateVersion = "25.05";
}
