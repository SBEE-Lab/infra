{ lib, ... }:
{
  options.services.sbee.nginx = {
    edgeVhosts = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options.reloadServices = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
          };
          options.group = lib.mkOption {
            type = lib.types.str;
            default = "nginx";
          };
        }
      );
      default = { };
      description = "Public edge virtual hosts with locally issued ACME certificates.";
    };

    localCertificates = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options.reloadServices = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
          };
          options.group = lib.mkOption {
            type = lib.types.str;
            default = "nginx";
          };
        }
      );
      default = { };
      description = "Locally issued certificates without an edge virtual host.";
    };

    streamProxies = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            listenPort = lib.mkOption { type = lib.types.port; };
            upstreamHost = lib.mkOption { type = lib.types.str; };
            upstreamPort = lib.mkOption { type = lib.types.port; };
            proxyTimeout = lib.mkOption {
              type = lib.types.str;
              default = "1h";
            };
          };
        }
      );
      default = { };
      description = "Public TCP services passed through without terminating TLS.";
    };
  };
}
