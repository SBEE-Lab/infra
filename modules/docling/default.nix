{ config, ... }:
let
  inherit (config.networking.sbee) hosts;
  authentikAuth = import ../authentik/nginx-locations.nix { inherit hosts; };
  domain = "docling.sjanglab.org";
  doclingPort = 5001;
  certDir = "/var/lib/acme/${domain}";
in
{
  imports = [
    ../acme/sync.nix
    ../gatus/check.nix
  ];

  gatusCheck.push = [
    {
      name = "Docling";
      group = "ai";
      url = "http://127.0.0.1:${toString doclingPort}/health";
    }
  ];

  acmeSyncer.mkReceiver = [
    { inherit domain; }
  ];

  # Docker container with GPU
  virtualisation.oci-containers = {
    backend = "docker";
    containers.docling = {
      image = "ghcr.io/docling-project/docling-serve-cu128:latest";
      ports = [ "127.0.0.1:${toString doclingPort}:5001" ];
      extraOptions = [ "--device=nvidia.com/gpu=all" ];
    };
  };

  # Nginx reverse proxy
  services.nginx = {
    enable = true;
    virtualHosts.${domain} = {
      forceSSL = true;
      sslCertificate = "${certDir}/fullchain.pem";
      sslCertificateKey = "${certDir}/key.pem";

      locations = authentikAuth.locations // {
        "/" = {
          proxyPass = "http://127.0.0.1:${toString doclingPort}";
          extraConfig = authentikAuth.protectLocation + ''
            client_max_body_size 100M;
            proxy_read_timeout 300s;
          '';
        };
      };
    };
  };

  # Firewall: tailscale0 only (80/443 already allowed in tailscale module)
}
