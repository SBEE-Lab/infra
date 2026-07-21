{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.rustfs;
  jsonFormat = pkgs.formats.json { };
  bucketType = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "Bucket name to ensure.";
      };

      versioning = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable and verify S3 bucket versioning.";
      };
    };
  };
  policyStatementType = lib.types.submodule {
    options = {
      effect = lib.mkOption {
        type = lib.types.enum [
          "Allow"
          "Deny"
        ];
        default = "Allow";
        description = "IAM statement effect.";
      };

      actions = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = "S3/admin actions allowed or denied by this statement.";
      };

      resources = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = "IAM resources covered by this statement.";
      };

      condition = lib.mkOption {
        type = lib.types.nullOr jsonFormat.type;
        default = null;
        description = "Optional IAM statement condition.";
      };
    };
  };
in
{
  options.services.rustfs = {
    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = config.networking.sbee.currentHost.wg-admin;
      defaultText = "config.networking.sbee.currentHost.wg-admin";
      description = "Address for the S3 API listener.";
    };

    apiPort = lib.mkOption {
      type = lib.types.port;
      default = 9100;
      description = "TCP port for the S3 API listener.";
    };

    consolePort = lib.mkOption {
      type = lib.types.port;
      default = 9101;
      description = "TCP port for the localhost-only console listener.";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/srv/rustfs/data";
      description = "RustFS object data directory.";
    };

    rootAccessKeyFile = lib.mkOption {
      type = lib.types.path;
      default = "/run/secrets/rustfs-access-key";
      description = "File containing the RustFS root access key for daemon bootstrap.";
    };

    rootSecretKeyFile = lib.mkOption {
      type = lib.types.path;
      default = "/run/secrets/rustfs-secret-key";
      description = "File containing the RustFS root secret key for daemon bootstrap.";
    };

    secretInstallService = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "sops-install-secrets.service";
      description = "systemd service that installs RustFS root credential files before daemon/bootstrap use.";
    };

    ensureBuckets = lib.mkOption {
      type = lib.types.listOf (lib.types.coercedTo lib.types.str (name: { inherit name; }) bucketType);
      default = [ ];
      description = "Buckets that must exist before backup jobs use RustFS.";
      example = [
        "backups"
        {
          name = "restore-drill";
          versioning = true;
        }
      ];
    };

    ensurePolicies = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options.statements = lib.mkOption {
            type = lib.types.listOf policyStatementType;
            default = [ ];
            description = "IAM policy statements.";
          };
        }
      );
      default = { };
      description = "Canned IAM policies that must exist before RustFS client users are attached.";
      example = {
        backup-writer.statements = [
          {
            actions = [
              "s3:PutObject"
              "s3:AbortMultipartUpload"
            ];
            resources = [ "arn:aws:s3:::backups/psi/*" ];
          }
        ];
      };
    };

    ensureUsers = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "RustFS access key / user name to ensure.";
            };

            secretKeyFile = lib.mkOption {
              type = lib.types.path;
              description = "File containing the secret key for this RustFS user.";
            };

            policies = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Canned policy names to attach to this RustFS user.";
            };
          };
        }
      );
      default = [ ];
      description = "RustFS users that must exist before backup jobs use the S3 API.";
    };

    monitoring = {
      gatus.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Register a Gatus readiness check for RustFS.";
      };

      loki.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Ship RustFS service logs to the central Loki instance.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.rustfs = {
      settings = {
        RUSTFS_ADDRESS = "${cfg.listenAddress}:${toString cfg.apiPort}";
        RUSTFS_CONSOLE_ENABLE = "true";
        RUSTFS_CONSOLE_ADDRESS = "127.0.0.1:${toString cfg.consolePort}";
        RUSTFS_VOLUMES = cfg.dataDir;
      };
      environmentFile = config.sops.templates.rustfs-env.path;
    };

    sops.templates.rustfs-env = {
      owner = cfg.user;
      inherit (cfg) group;
      mode = "0400";
      content = ''
        RUSTFS_ACCESS_KEY=${config.sops.placeholder.rustfs-access-key}
        RUSTFS_SECRET_KEY=${config.sops.placeholder.rustfs-secret-key}
      '';
    };

    systemd.tmpfiles.rules = [
      "d /srv/rustfs 0750 ${cfg.user} ${cfg.group} -"
    ];

    systemd.services.rustfs = {
      after = [
        "srv.mount"
      ]
      ++ lib.optional (cfg.secretInstallService != null) cfg.secretInstallService;
      requires = lib.optional (cfg.secretInstallService != null) cfg.secretInstallService;
      unitConfig = {
        RequiresMountsFor = "/srv";
        StartLimitIntervalSec = "5min";
      };
      serviceConfig = {
        WorkingDirectory = "/var/lib/rustfs";
        StateDirectory = "rustfs";
        LogsDirectory = "rustfs";
        ProtectSystem = "strict";
        UMask = "0077";
        ReadWritePaths = [
          cfg.dataDir
          "/var/lib/rustfs"
          "/var/log/rustfs"
        ];
        StandardOutput = "journal";
        StandardError = "journal";
      };
    };

    networking.firewall.interfaces.wg-admin.allowedTCPPorts = [ cfg.apiPort ];
    environment.systemPackages = [ cfg.package ];
  };
}
