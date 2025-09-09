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

    gateway = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Default gateway for this host
      '';
    };

    location = mkOption {
      type = types.enum [
        "IDC"
        "office"
        "terraform"
      ];
      default = null;
      description = ''
        Physical location of this host

        IDC: INU datacenter
        office: SBEE lab office
        terraform: provisioned cloud instance
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
  };
  config = {
    warnings =
      lib.optional
        (
          !(config.networking.sbee.hosts ? ${config.networking.hostName})
          && config.networking.hostName != "nixos" # we dont care about nixos netboot/installer images
        )
        "Please add network configuration for ${config.networking.hostName}. None found in ${./hosts.nix}";

    networking.sbee.hosts = {
      psi = {
        ipv4 = "117.16.251.37";
        mac = "bc:fc:e7:52:e1:ab";
        gateway = "117.16.251.254";
        location = "IDC";
      };
      rho = {
        ipv4 = "10.80.169.39";
        mac = "9c:6b:00:9e:fa:de";
        gateway = "10.80.169.254";
        location = "office";
      };
      tau = {
        ipv4 = "10.80.169.40";
        mac = "";
        gateway = "10.80.169.254";
        location = "office";
      };
      eta = {
        ipv4 = "158.247.197.232";
        mac = "";
        gateway = "10.80.169.254";
        location = "terraform";
      };
    };
  };
}
