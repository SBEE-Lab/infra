{
  config,
  self,
  ...
}:
let
  certs = config.sops.secrets;
in
{
  imports = [ self.inputs.nix-grpc-store.nixosModules.server ];

  sops.secrets = {
    nix-grpc-ca-cert = {
      owner = "nix-grpc-daemon";
      group = "nix-grpc-daemon";
      mode = "0444";
    };
    nix-grpc-server-cert = {
      owner = "nix-grpc-daemon";
      group = "nix-grpc-daemon";
      mode = "0444";
      restartUnits = [ "nix-grpc-daemon.service" ];
    };
    nix-grpc-server-key = {
      owner = "nix-grpc-daemon";
      group = "nix-grpc-daemon";
      mode = "0400";
    };
  };

  services.nix-grpc-daemon = {
    enable = true;
    # Remote builders import unsigned outputs from authenticated clients.
    trustClients = true;
    tls = {
      certFile = certs.nix-grpc-server-cert.path;
      keyFile = certs.nix-grpc-server-key.path;
      clientCaFile = certs.nix-grpc-ca-cert.path;
    };
  };

  networking.firewall.interfaces = {
    wg-admin.allowedTCPPorts = [ 50051 ];
    tailscale0.allowedTCPPorts = [ 50051 ];
  };
}
