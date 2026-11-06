{ config, self, ... }:
{
  imports = [ self.inputs.flakelet.nixosModules.flakelet ];

  # The flakelet owns the unit; sops cannot restart it.
  sops.secrets.tribuchet-worker-key = { };

  # Imports build inputs unsigned.
  nix.settings.trusted-users = [ "tribuchet" ];

  services.flakelets = {
    enable = true;
    services.tribuchet-worker = {
      flake = "github:Mic92/tribuchet";
      output = "flakelets.worker";
      autoUpdate.enable = true;
      settings = {
        keyFile = config.sops.secrets.tribuchet-worker-key.path;
        worker = {
          hub = "https://citra.n:7437";
          ca-cert = "${./ca.crt}";
          cert = "${./worker.crt}";
          # Shares psi with the SBEE nixbot.
          max-jobs = 12;
          # FODs reach only the public internet on fetcher ports; first match wins.
          fod-network = {
            default = "deny";
            rules = [
              {
                action = "deny";
                dst = "private";
              }
              # INU ranges that trust on-campus origin.
              {
                action = "deny";
                dst = "117.16.248.0/22";
              }
              {
                action = "deny";
                dst = "117.16.190.0/23";
              }
              {
                action = "deny";
                dst = "117.16.224.0/20";
              }
              {
                action = "allow";
                proto = "tcp";
                dst = "any";
                ports = [
                  "80"
                  "443"
                  "22"
                  "9418"
                  "3690"
                  "873"
                ];
              }
              {
                action = "allow";
                proto = "udp";
                dst = "any";
                ports = [ "443" ];
              }
            ];
          };
        };
      };
    };
  };
}
