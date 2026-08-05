{
  config,
  lib,
  self,
  ...
}:
let
  inherit (config.networking) hostName;
in
{
  imports = [ self.inputs.nix-grpc-store.nixosModules.server ];

  config = lib.mkIf (hostName == "psi") {
    services.nix-grpc-daemon = {
      enable = true;
      # Remote builders import unsigned outputs from the client-side daemon.
      # Access is limited to wg-admin during initial rollout.
      trustClients = true;
    };

    networking.firewall.interfaces.wg-admin.allowedTCPPorts = [ 50051 ];
  };
}
