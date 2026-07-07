{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
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
    enable = lib.mkEnableOption "RustFS S3-compatible object storage";

    package = lib.mkOption {
      type = lib.types.package;
      default = inputs.rustfs.packages.${pkgs.stdenv.hostPlatform.system}.default;
      defaultText = "inputs.rustfs.packages.\${pkgs.stdenv.hostPlatform.system}.default";
      description = "RustFS package to run.";
    };

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

    monitoring.gatus.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Register a Gatus readiness check for RustFS.";
    };
  };
}
