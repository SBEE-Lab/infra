{
  config,
  lib,
  ...
}:
let
  cfg = config.services.sbee.nginx;
  streamConfig = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: proxy: ''
      upstream ${name} {
        server ${proxy.upstreamHost}:${toString proxy.upstreamPort};
      }

      server {
        listen ${toString proxy.listenPort};
        proxy_connect_timeout 5s;
        proxy_timeout ${proxy.proxyTimeout};
        proxy_socket_keepalive on;
        proxy_pass ${name};
      }
    '') cfg.streamProxies
  );
in
{
  imports = [
    ./options.nix
    ../acme
  ];

  assertions = [
    {
      assertion =
        lib.intersectLists (lib.attrNames cfg.edgeVhosts) (lib.attrNames cfg.localCertificates) == [ ];
      message = "nginx certificate cannot be both vhost-bound and certificate-only";
    }
  ];

  services.nginx = {
    enable = true;
    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;
    commonHttpConfig = ''
      add_header Strict-Transport-Security "max-age=31536000" always;
    '';
    streamConfig = lib.mkIf (cfg.streamProxies != { }) streamConfig;
    virtualHosts = lib.mapAttrs (domain: _: {
      forceSSL = true;
      useACMEHost = domain;
    }) cfg.edgeVhosts;
  };

  security.acme.certs = lib.mapAttrs (domain: certificate: {
    inherit domain;
    dnsProvider = "cloudflare";
    environmentFile = config.sops.secrets.cloudflare-credentials.path;
    webroot = null;
    inherit (certificate) group reloadServices;
  }) (cfg.edgeVhosts // cfg.localCertificates);

  networking.firewall.allowedTCPPorts = [
    80
    443
  ]
  ++ map (proxy: proxy.listenPort) (lib.attrValues cfg.streamProxies);
}
