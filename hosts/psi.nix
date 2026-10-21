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
    ../modules/backup/borg.nix
    ../modules/niks3
    # ../modules/vllm
    ../modules/biodb
    ../modules/biodb/databases.nix
  ];

  disko.rootDisk = "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_4TB_S7DPNU0Y404280K";

  disko.xfsMdadm = {
    enable = true;
    arrays = {
      # SSD RAID0 for workspace (16TB total)
      workspace = {
        level = 0;
        disks.ssd1 = "/dev/disk/by-id/nvme-Samsung_SSD_9100_PRO_8TB_S7YHNJ0YA05025J";
        disks.ssd2 = "/dev/disk/by-id/nvme-Samsung_SSD_9100_PRO_8TB_S7YHNJ0YA02750H";
        mountpoint = "/workspace";
        extraXfsOptions = [
          "allocsize=16m"
        ];
      };
      # HDD RAID1 for data (30TB usable)
      data = {
        level = 1;
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

  sops.secrets.github-actions-runner-token = {
    mode = "0400";
    restartUnits = [ "github-runner-release-runner.service" ];
  };

  services.github-runners.release-runner = {
    enable = true;
    url = "https://github.com/SBEE-Lab";
    name = "release-runner";
    runnerGroup = "release-runner";
    tokenFile = config.sops.secrets.github-actions-runner-token.path;
    tokenType = "access";
    replace = true;
    ephemeral = false;
    extraLabels = [
      "psi"
      "gpu"
      "trusted-release"
      "container-release"
    ];
    extraPackages = with pkgs; [
      buildkit
      curl
      docker-buildx
      docker-client
      jq
      skopeo
      syft
      zstd
    ];
    extraEnvironment = {
      DOCKER_BUILDKIT = "1";
      DOCKER_HOST = "unix:///run/docker.sock";
      DOCKER_CLI_PLUGIN_EXTRA_DIRS = "${pkgs.docker-buildx}/libexec/docker/cli-plugins";
    };
    serviceOverrides = {
      # Docker socket access is equivalent to root on psi. Restrict this runner
      # group to trusted release workflows and never run fork or PR code here.
      PrivateUsers = false;
      SupplementaryGroups = [ "docker" ];
    };
  };

  systemd.services.github-runner-release-runner = {
    requires = [ "docker.service" ];
    after = [ "docker.service" ];
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

  services.prometheus.exporters.nvidia-gpu = {
    enable = true;
    listenAddress = config.networking.sbee.currentHost.wg-admin;
    port = 9835;
    extraFlags = [ "--no-shutdown-on-error" ];
  };

  networking.firewall = {
    interfaces."wg-admin".allowedTCPPorts = [
      9835 # nvidia-gpu exporter
    ];
  };

  programs.singularity = {
    enable = true;
    package = pkgs.apptainer;
  };

  system.stateVersion = "25.05";
}
