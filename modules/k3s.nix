{ config, ... }:
{
  services.k3s = {
    enable = true;
    role = "server";
    disable = [
      "traefik"
      "servicelb"
    ];
    # Keep the certificate-authenticated API on the administrative WireGuard network.
    extraFlags = [
      "--bind-address=${config.networking.sbee.currentHost.wg-admin}"
      "--advertise-address=${config.networking.sbee.currentHost.wg-admin}"
      "--node-ip=${config.networking.sbee.currentHost.wg-admin}"
      "--tls-san=${config.networking.sbee.currentHost.wg-admin}"
      "--tls-san=k3s.sjanglab.org"
    ];
  };
}
