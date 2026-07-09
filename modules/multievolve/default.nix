{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.networking.sbee) hosts;
  authentikAuth = import ../authentik/nginx-locations.nix { inherit hosts; };
  domain = "multievolve.sjanglab.org";
  port = 8501;
  certDir = "/var/lib/acme/${domain}";
in
{
  imports = [
    inputs.multievolve-nix.nixosModules.default
    ../acme/sync.nix
    ../gatus/check.nix
  ];

  gatusCheck.push = [
    {
      name = "MULTI-evolve";
      group = "apps";
      checks = [
        { url = "http://127.0.0.1:${toString port}/_stcore/health"; }
        {
          url = "https://${domain}/";
          expectedStatus = 302;
        }
      ];
    }
  ];

  acmeSyncer.mkReceiver = [
    {
      inherit domain;
      user = "acme-sync-multievolve";
    }
  ];

  services.multievolve-streamlit = {
    enable = true;
    host = "127.0.0.1";
    inherit port;
    workingDirectory = "/workspace/multievolve";
    extraGroups = [
      "render"
      "video"
    ];
    environment = {
      CUDA_VISIBLE_DEVICES = "0";
      LD_LIBRARY_PATH = lib.concatStringsSep ":" [
        "/run/opengl-driver/lib"
        "${pkgs.cudaPackages.cuda_cudart}/lib"
        "${pkgs.cudaPackages.libcublas}/lib"
      ];
    };
  };

  services.nginx = {
    enable = true;
    recommendedTlsSettings = true;

    virtualHosts.${domain} = {
      forceSSL = true;
      sslCertificate = "${certDir}/fullchain.pem";
      sslCertificateKey = "${certDir}/key.pem";
      extraConfig = ''
        access_log /var/log/nginx/access-audit/multievolve.log nginx_access_json;
      '';

      locations = authentikAuth.locations // {
        "/" = {
          proxyPass = "http://127.0.0.1:${toString port}";
          proxyWebsockets = true;
          extraConfig = authentikAuth.protectLocation + ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_buffering off;
            proxy_read_timeout 600s;
            proxy_send_timeout 600s;
            client_max_body_size 1G;
          '';
        };
      };
    };
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 443 ];
}
