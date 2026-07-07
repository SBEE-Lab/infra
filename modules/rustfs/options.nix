{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
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

    monitoring.gatus.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Register a Gatus readiness check for RustFS.";
    };
  };
}
