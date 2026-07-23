{
  config,
  inputs,
  lib,
  pkgs,
  self,
  ...
}:
let
  inherit (config.networking.sbee) hosts;
  wgAdminAddr = config.networking.sbee.currentHost.wg-admin;
  omnigraphBucket = "omnigraph";
  omnigraphCluster = "s3://${omnigraphBucket}/clusters/main";
  omnigraphPrefix = "clusters/main";
  omnigraphBucketArn = "arn:aws:s3:::${omnigraphBucket}";
  omnigraphObjectArn = "${omnigraphBucketArn}/${omnigraphPrefix}/*";
in
{
  imports = [
    ../modules/hardware/asrock-deskmini-x600.nix
    ../modules/disko/xfs-root.nix
    ../modules/disko/xfs-mdadm.nix
    ../modules/wake-on-lan.nix
    ../modules/tailscale
    ../modules/postgresql/replica.nix
    ../modules/rustfs
    inputs.rag-nix.nixosModules.omnigraph
    ../modules/omnigraph/reverse-proxy.nix
    ../modules/backup/primary.nix
    ../modules/monitoring/vector/monitor-services.nix
    ../modules/nextcloud
    ../modules/n8n
    ../modules/vaultwarden/reverse-proxy.nix
  ];

  disko.rootDisk = "/dev/disk/by-id/nvme-eui.00000000000000006479a79cdac0038f";
  disko.xfsMdadm = {
    enable = true;
    arrays = {
      # HDD RAID0 for data (4TB total)
      data = {
        disks.hdd1 = "/dev/disk/by-id/ata-WDC_WD20SPZX-00UA7T0_WD-WXB2A153HDND";
        disks.hdd2 = "/dev/disk/by-id/ata-WDC_WD20SPZX-00UA7T0_WD-WX62AC455S8R";
        mountpoint = "/srv";
        extraXfsOptions = [
          "largeio"
          "allocsize=64m"
          "filestreams"
        ];
      };
    };
  };

  networking.hostName = "tau";

  sops.secrets = {
    rustfs-access-key = {
      owner = "rustfs";
      group = "rustfs";
      mode = "0400";
    };
    rustfs-secret-key = {
      owner = "rustfs";
      group = "rustfs";
      mode = "0400";
    };
    omnigraph-bearer-tokens = {
      owner = "omnigraph";
      group = "omnigraph";
      mode = "0400";
    };
    omnigraph-env = {
      owner = "omnigraph";
      group = "omnigraph";
      mode = "0400";
    };
    omnigraph-rustfs-server-secret-key = {
      owner = "rustfs";
      group = "rustfs";
      mode = "0400";
    };
    omnigraph-rustfs-admin-secret-key = {
      owner = "rustfs";
      group = "rustfs";
      mode = "0400";
    };
  };

  environment.systemPackages = [ self.packages.${pkgs.stdenv.hostPlatform.system}.omnigraph-cli ];

  services = {
    rustfs = {
      enable = true;
      ensureBuckets = [ omnigraphBucket ];
      ensurePolicies = {
        omnigraph-server.statements = [
          {
            actions = [ "s3:ListBucket" ];
            resources = [ omnigraphBucketArn ];
            condition.StringLike."s3:prefix" = [
              omnigraphPrefix
              "${omnigraphPrefix}/*"
            ];
          }
          {
            actions = [ "s3:GetBucketLocation" ];
            resources = [ omnigraphBucketArn ];
          }
          {
            actions = [ "s3:GetObject" ];
            resources = [ omnigraphObjectArn ];
          }
        ];

        omnigraph-admin.statements = [
          {
            actions = [ "s3:ListBucket" ];
            resources = [ omnigraphBucketArn ];
            condition.StringLike."s3:prefix" = [
              omnigraphPrefix
              "${omnigraphPrefix}/*"
            ];
          }
          {
            actions = [ "s3:GetBucketLocation" ];
            resources = [ omnigraphBucketArn ];
          }
          {
            actions = [
              "s3:GetObject"
              "s3:PutObject"
              "s3:DeleteObject"
              "s3:AbortMultipartUpload"
              "s3:ListMultipartUploadParts"
            ];
            resources = [ omnigraphObjectArn ];
          }
        ];
      };
      ensureUsers = [
        {
          name = "omnigraph-server";
          secretKeyFile = config.sops.secrets.omnigraph-rustfs-server-secret-key.path;
          policies = [ "omnigraph-server" ];
        }
        {
          name = "omnigraph-admin";
          secretKeyFile = config.sops.secrets.omnigraph-rustfs-admin-secret-key.path;
          policies = [ "omnigraph-admin" ];
        }
      ];
    };

    omnigraph = {
      enable = true;
      # Enable after omnigraph-clusters applies the first cluster revision to RustFS.
      autoStart = false;
      cluster = omnigraphCluster;
      listenAddress = "127.0.0.1";
      port = 8300;
      bearerTokensFile = config.sops.secrets.omnigraph-bearer-tokens.path;
      environment = {
        AWS_ACCESS_KEY_ID = "omnigraph-server";
        AWS_ALLOW_HTTP = "true";
        AWS_ENDPOINT_URL_S3 = "http://${wgAdminAddr}:9100";
        AWS_REGION = "us-east-1";
        AWS_S3_FORCE_PATH_STYLE = "true";

        OMNIGRAPH_EMBED_PROVIDER = "openai-compatible";
        OMNIGRAPH_EMBED_BASE_URL = "http://${hosts.psi.wg-admin}:8201/v1";
        OMNIGRAPH_EMBED_MODEL = "Qwen/Qwen3-Embedding-0.6B";
        OPENAI_API_KEY = "unused-for-internal-tei";
      };
      environmentFiles = [ config.sops.secrets.omnigraph-env.path ];
    };

    vector.settings = lib.sbee.monitoring.mkJournaldLokiPipeline {
      name = "omnigraph";
      hostName = config.networking.hostName;
      endpoint = "http://${hosts.rho.wg-admin}:3100";
      units = [ "omnigraph-server.service" ];
    };

    sbee.backups.primary = {
      psiProtected.enable = true;
      postgresql.enable = true;
    };
  };

  system.stateVersion = "25.05";
}
