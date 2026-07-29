{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  cfg = config.services.biomcp;
  system = pkgs.stdenv.hostPlatform.system;
  inherit (cfg) package;

  serverArgs = [
    (lib.getExe package)
    "serve-http"
    "--host"
    cfg.listenAddress
    "--port"
    (toString cfg.port)
  ]
  ++ lib.optionals (cfg.allowedHosts != [ ]) [
    "--allowed-hosts"
    (lib.concatStringsSep "," cfg.allowedHosts)
  ]
  ++ cfg.extraArgs;
in
{
  options.services.biomcp = {
    enable = lib.mkEnableOption "BioMCP HTTP MCP server";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${system}.biomcp;
      defaultText = lib.literalExpression "self.packages.\${pkgs.stdenv.hostPlatform.system}.biomcp";
      description = "BioMCP package to run.";
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address BioMCP binds to.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "TCP port BioMCP listens on.";
    };

    allowedHosts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Host header values accepted by BioMCP. Empty allows any host.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open the BioMCP port on the configured firewall interface.";
    };

    firewallInterface = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Firewall interface where the BioMCP port is opened. Null opens globally when openFirewall is true.";
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Additional environment variables for BioMCP. Do not put secrets here.";
    };

    environmentFiles = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      description = "Environment files loaded by systemd. Use this for API keys from sops-nix.";
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra arguments passed to `biomcp serve-http`.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.biomcp = {
      description = "BioMCP HTTP MCP server";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        HOME = "/var/lib/biomcp";
        XDG_CACHE_HOME = "/var/cache/biomcp";
        XDG_CONFIG_HOME = "/var/lib/biomcp/config";
        XDG_DATA_HOME = "/var/lib/biomcp/data";
        SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      }
      // cfg.environment;

      serviceConfig = {
        Type = "simple";
        ExecStart = lib.escapeShellArgs serverArgs;
        EnvironmentFile = cfg.environmentFiles;
        Restart = "on-failure";
        RestartSec = "10s";

        DynamicUser = true;
        User = "biomcp";
        StateDirectory = "biomcp";
        CacheDirectory = "biomcp";
        WorkingDirectory = "/var/lib/biomcp";

        CapabilityBoundingSet = "";
        DevicePolicy = "closed";
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        PrivateUsers = true;
        ProcSubset = "pid";
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectProc = "invisible";
        ProtectSystem = "strict";
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
        ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        UMask = "0077";
      };
    };

    networking.firewall = lib.mkIf cfg.openFirewall (
      if cfg.firewallInterface == null then
        {
          allowedTCPPorts = [ cfg.port ];
        }
      else
        {
          interfaces.${cfg.firewallInterface}.allowedTCPPorts = [ cfg.port ];
        }
    );
  };
}
