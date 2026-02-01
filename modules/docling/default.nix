{ pkgs, ... }:
let
  domain = "docling.sjanglab.org";
  doclingPort = 5001;
  certDir = "/var/lib/acme/${domain}";
  acmeSyncPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO7mZ/UfOMpnrHaIigljsGWXCQAovWezdPpA3WQy1Qgu acme-sync@eta";
in
{
  # acme-sync user for receiving certificates from eta
  users.users.acme-sync = {
    isSystemUser = true;
    group = "acme-sync";
    home = certDir;
    shell = pkgs.bashInteractive;
    openssh.authorizedKeys.keys = [ acmeSyncPubKey ];
  };
  users.groups.acme-sync.members = [ "nginx" ];

  # Certificate directory
  systemd.tmpfiles.rules = [
    "d ${certDir} 0750 acme-sync acme-sync - -"
  ];

  # Reload nginx on cert update
  systemd.services.acme-sync-reload-nginx = {
    description = "Reload nginx after certificate sync";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.systemd}/bin/systemctl reload nginx";
    };
  };
  systemd.paths.acme-sync-watch = {
    wantedBy = [ "multi-user.target" ];
    pathConfig = {
      PathChanged = "${certDir}/fullchain.pem";
      Unit = "acme-sync-reload-nginx.service";
    };
  };

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

      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString doclingPort}";
        extraConfig = ''
          client_max_body_size 100M;
          proxy_read_timeout 300s;
        '';
      };
    };
  };

  # Firewall: tailscale0 only (80/443 already allowed in tailscale module)
}
