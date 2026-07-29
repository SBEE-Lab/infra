{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.hermes-agent;
  agentBridge = "br-agents";
  hostAddress = "10.233.0.1";
  localAddress = "10.233.0.10";
in
{
  config = lib.mkIf cfg.enable {
    networking = {
      bridges.${agentBridge}.interfaces = [ ];
      interfaces.${agentBridge}.ipv4.addresses = [
        {
          address = hostAddress;
          prefixLength = 24;
        }
      ];

      nat = {
        enable = true;
        inherit (cfg) externalInterface;
        internalInterfaces = [ agentBridge ];
      };

      # Tau still uses NixOS' iptables firewall backend. Dedicated chains keep
      # agent policy isolated from unrelated host firewall rules.
      firewall.extraCommands = ''
        iptables -w -N hermes-input 2>/dev/null || true
        iptables -w -F hermes-input
        iptables -w -A hermes-input -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
        iptables -w -A hermes-input -j DROP
        iptables -w -D INPUT -i ${agentBridge} -j hermes-input 2>/dev/null || true
        iptables -w -I INPUT 1 -i ${agentBridge} -j hermes-input

        iptables -w -N hermes-forward 2>/dev/null || true
        iptables -w -F hermes-forward
        iptables -w -A hermes-forward -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
        iptables -w -A hermes-forward -o ${cfg.externalInterface} -p tcp --dport 443 -j ACCEPT
        iptables -w -A hermes-forward -o ${cfg.externalInterface} -p udp --dport 53 -j ACCEPT
        iptables -w -A hermes-forward -o ${cfg.externalInterface} -p tcp --dport 53 -j ACCEPT
        iptables -w -A hermes-forward -j DROP
        iptables -w -D FORWARD -i ${agentBridge} -j hermes-forward 2>/dev/null || true
        iptables -w -I FORWARD 1 -i ${agentBridge} -j hermes-forward
      '';
      firewall.extraStopCommands = ''
        iptables -w -D INPUT -i ${agentBridge} -j hermes-input 2>/dev/null || true
        iptables -w -F hermes-input 2>/dev/null || true
        iptables -w -X hermes-input 2>/dev/null || true
        iptables -w -D FORWARD -i ${agentBridge} -j hermes-forward 2>/dev/null || true
        iptables -w -F hermes-forward 2>/dev/null || true
        iptables -w -X hermes-forward 2>/dev/null || true
      '';
    };

    containers.hermes = {
      privateNetwork = true;
      hostBridge = agentBridge;
      localAddress = "${localAddress}/24";

      config = _: {
        networking = {
          useHostResolvConf = false;
          nftables.enable = true;
          defaultGateway = {
            address = hostAddress;
            interface = "eth0";
          };
          inherit (cfg) nameservers;
          firewall.extraInputRules = lib.optionalString cfg.enableDashboard ''
            ip saddr ${hostAddress} tcp dport 9119 accept
          '';
        };

        systemd.sockets.hermes-dashboard-proxy = lib.mkIf cfg.enableDashboard {
          description = "Private bridge socket for the Hermes dashboard";
          wantedBy = [ "sockets.target" ];
          socketConfig.ListenStream = "${localAddress}:9119";
        };

        systemd.services.hermes-dashboard-proxy = lib.mkIf cfg.enableDashboard {
          description = "Proxy the private bridge to the loopback-only Hermes dashboard";
          after = [ "hermes-dashboard.service" ];
          requires = [ "hermes-dashboard.service" ];
          serviceConfig = {
            User = "hermes";
            Group = "hermes";
            ExecStart = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd 127.0.0.1:9119";
            NoNewPrivileges = true;
            PrivateTmp = true;
            ProtectHome = true;
            ProtectSystem = "strict";
          };
        };
      };
    };
  };
}
