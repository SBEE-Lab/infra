# https://github.com/TUM-DSE/doctor-cluster-config/tree/4702b65ba00ccaf932fa87c71eee5a5b584896ab/modules/hosts.nix
{
  lib,
  config,
  ...
}:
let
  hostOptions = with lib; {
    ipv4 = mkOption {
      type = types.str;
      description = ''
        own ipv4 address
      '';
    };

    mac = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        MAC address of the NIC port used as a gateway
      '';
    };

    wg-admin = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        WireGuard interface for admin access (unified)
      '';
    };

    # Legacy options - kept for migration, will be removed
    wg-mgnt = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Wireguard interface for management (wg-mgnt) address
      '';
    };

    wg-serv = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Wireguard interface for service (wg-serv) address
      '';
    };

    gateway = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Default gateway for this host
      '';
    };
    tags = mkOption {
      type = types.listOf (
        types.enum [
          "public-ip"
          "nat-behind"
          "lab-network"
          "kren-dns"
          "vps-network"
        ]
      );
      default = [ ];
      description = ''
        Tags for categorizing host configuration
        - "public-ip": Host has public IP and can accept incoming connections
        - "nat-behind": Host is behind NAT
        - "lab-network": Host is part of lab internal network
        - "vps-network": Host is part of vps(vultr) network
        - "kren-dns": Host uses KREN network
      '';
    };
  };
in
{
  options = with lib; {
    networking.sbee.hosts = mkOption {
      type = with types; attrsOf (submodule [ { options = hostOptions; } ]);
      description = "A host in our cluster";
    };
    networking.sbee.currentHost = mkOption {
      type = with types; submodule [ { options = hostOptions; } ];
      default = config.networking.sbee.hosts.${config.networking.hostName};
      description = "The host that is described by this configuration";
    };
    networking.sbee.others = mkOption {
      type = with types; attrsOf (submodule [ { options = hostOptions; } ]);
      default = lib.filterAttrs (
        name: _: name != config.networking.hostName
      ) config.networking.sbee.hosts;
      description = "All hosts except the current one";
    };
  };
  config = {
    # Generate /etc/hosts entries for all hosts using WireGuard admin IPs
    # This allows servers to resolve each other by hostname (e.g., ssh psi)
    networking.hosts = lib.mkMerge (
      lib.mapAttrsToList (
        name: host:
        lib.optionalAttrs (host.wg-admin != null) {
          ${host.wg-admin} = [ name ];
        }
      ) config.networking.sbee.hosts
    );

    warnings =
      lib.optional
        (
          !(config.networking.sbee.hosts ? ${config.networking.hostName})
          && config.networking.hostName != "nixos" # we dont care about nixos netboot/installer images
        )
        "Please add network configuration for ${config.networking.hostName}. None found in ${./hosts.nix}";

    networking.sbee.hosts = {
      eta = {
        ipv4 = "141.164.53.203";
        gateway = "141.164.52.1";
        mac = "56:00:05:a5:b3:57";
        wg-admin = "10.100.0.1";
        wg-mgnt = "10.100.0.1";
        wg-serv = "10.200.0.1";
        tags = [
          "public-ip"
          "vps-network"
        ];
      };
      psi = {
        ipv4 = "117.16.251.37";
        gateway = "117.16.251.254";
        mac = "bc:fc:e7:52:e1:ab";
        wg-admin = "10.100.0.2";
        wg-mgnt = "10.100.0.2";
        wg-serv = "10.200.0.2";
        tags = [
          "public-ip"
          "kren-dns"
        ];
      };
      rho = {
        ipv4 = "10.80.169.39";
        gateway = "10.80.169.254";
        mac = "9c:6b:00:9e:fa:de";
        wg-admin = "10.100.0.3";
        wg-mgnt = "10.100.0.3";
        wg-serv = "10.200.0.3";
        tags = [
          "nat-behind"
          "lab-network"
          "kren-dns"
        ];
      };
      tau = {
        ipv4 = "10.80.169.40";
        gateway = "10.80.169.254";
        mac = "9c:6b:00:9e:f8:ef";
        wg-admin = "10.100.0.4";
        wg-mgnt = "10.100.0.4";
        wg-serv = "10.200.0.4";
        tags = [
          "nat-behind"
          "lab-network"
          "kren-dns"
        ];
      };
    };
  };
}
