{ config, ... }:
{
  # TLS termination and client authentication stay on psi. Eta only makes the
  # NATed builder reachable while forwarding over wg-admin.
  services.sbee.nginx.streamProxies.nix_grpc_psi = {
    listenPort = 50051;
    upstreamHost = config.networking.sbee.hosts.psi.wg-admin;
    upstreamPort = 50051;
    proxyTimeout = "24h";
  };
}
