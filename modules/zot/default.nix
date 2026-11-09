{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.zot;
  json = pkgs.formats.json { };
  rawConfig = json.generate "zot.json" cfg.settings;
  rootDirectory = cfg.settings.storage.rootDirectory or "/var/lib/zot";
  externalRoot = !lib.hasPrefix "/var/lib/zot" rootDirectory;
  checkedConfig =
    pkgs.runCommand "zot-checked.json"
      {
        nativeBuildInputs = [
          cfg.package
          pkgs.python3
        ];
      }
      ''
        python3 ${./validate-config.py} ${rawConfig} validation.json
        zot verify validation.json
        cp ${rawConfig} "$out"
      '';
in
{
  options.services.zot = {
    enable = lib.mkEnableOption "zot OCI registry";
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ../../packages/zot { zui = pkgs.callPackage ../../packages/zui { }; };
      description = "Zot server package.";
    };
    settings = lib.mkOption {
      inherit (json) type;
      default = { };
      description = ''
        Freeform zot JSON configuration. Keep secrets outside the Nix store:
        reference credentials as /run/credentials/zot.service/NAME.
        JSON credentials (OIDC and session keys) need a .json credential name,
        since zot chooses their decoder from the filename extension.
        A local storage.rootDirectory outside /var/lib/zot is created for the
        zot user and made writable.
        Zot hot-reloads its supported settings (including ACL and retention).
        For changes outside that set, such as listener or storage paths, zot
        logs a warning; explicitly restart zot.service to apply those changes.
      '';
    };
    credentials = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      default = { };
      description = "Runtime secret paths loaded through systemd LoadCredential.";
    };
    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Runtime environment file, for example for S3 credentials.";
    };
  };
  config = lib.mkIf cfg.enable {
    environment.etc."zot/config.json".source = checkedConfig;
    # A static user, unlike DynamicUser, can own storage outside StateDirectory.
    users.users.zot = {
      isSystemUser = true;
      group = "zot";
    };
    users.groups.zot = { };
    systemd.tmpfiles.rules = lib.optional externalRoot "d ${rootDirectory} 0700 zot zot - -";
    systemd.services.zot = {
      description = "Zot OCI registry";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      # v2.1.23 polls file identity, including /etc symlink replacements. Keep
      # settings out of the unit so NixOS switches hot-reload without restart.
      restartTriggers = [ ];
      serviceConfig = {
        ExecStart = "${lib.getExe cfg.package} serve /etc/zot/config.json";
        LoadCredential = lib.mapAttrsToList (name: path: "${name}:${path}") cfg.credentials;
        EnvironmentFile = lib.mkIf (cfg.environmentFile != null) cfg.environmentFile;
        User = "zot";
        Group = "zot";
        StateDirectory = "zot";
        ReadWritePaths = lib.optional externalRoot rootDirectory;
        WorkingDirectory = "/var/lib/zot";
        UMask = "0077";
        Restart = "on-failure";
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
        ];
        CapabilityBoundingSet = [ ];
      };
    };
  };
}
