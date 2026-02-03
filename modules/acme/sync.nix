# ACME certificate rsync sync module
#
# Usage:
#   imports = [ ../acme/sync.nix ];
#   acmeSyncer.mkSender = [ { domain = "example.com"; serviceName = "acme-sync-to-host"; remoteHost = "10.0.0.1"; } ];
#   acmeSyncer.mkReceiver = [ { domain = "example.com"; } ];
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.acmeSyncer;

  acmeSyncPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO7mZ/UfOMpnrHaIigljsGWXCQAovWezdPpA3WQy1Qgu acme-sync@eta";
in
{
  options.acmeSyncer = {
    mkSender = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            domain = lib.mkOption { type = lib.types.str; };
            serviceName = lib.mkOption { type = lib.types.str; };
            remoteUser = lib.mkOption {
              type = lib.types.str;
              default = "acme-sync";
            };
            remoteHost = lib.mkOption { type = lib.types.str; };
          };
        }
      );
      default = [ ];
    };

    mkReceiver = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            domain = lib.mkOption { type = lib.types.str; };
            user = lib.mkOption {
              type = lib.types.str;
              default = "acme-sync";
            };
            reloadService = lib.mkOption {
              type = lib.types.str;
              default = "nginx";
            };
            extraGroupMembers = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ "nginx" ];
            };
          };
        }
      );
      default = [ ];
    };
  };

  # Fixed-size list for lib.mkMerge to avoid infinite recursion.
  # Dynamic content lives inside attrset VALUES (lazy), not in the list structure.
  config = lib.mkMerge [
    # --- Senders ---
    {
      security.acme.certs = builtins.listToAttrs (
        map (
          s:
          lib.nameValuePair s.domain {
            postRun = ''
              ${pkgs.systemd}/bin/systemctl start --no-block ${s.serviceName}.service || true
            '';
          }
        ) cfg.mkSender
      );

      systemd.services = builtins.listToAttrs (
        map (
          s:
          lib.nameValuePair s.serviceName {
            description = "Sync ${s.domain} certificate to ${s.remoteHost}";
            serviceConfig = {
              Type = "oneshot";
              User = "acme";
              ExecStart = pkgs.writeShellScript "sync-${s.serviceName}" ''
                ${pkgs.rsync}/bin/rsync \
                  -e "${pkgs.openssh}/bin/ssh -i ${config.sops.secrets.acme-sync-ssh-key.path} -p 10022 -o StrictHostKeyChecking=accept-new" \
                  -avz --chmod=D750,F640 \
                  /var/lib/acme/${s.domain}/ \
                  ${s.remoteUser}@${s.remoteHost}:/var/lib/acme/${s.domain}/
              '';
            };
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
          }
        ) cfg.mkSender
      );
    }

    # Shared SSH key (only when senders exist)
    (lib.mkIf (cfg.mkSender != [ ]) {
      sops.secrets.acme-sync-ssh-key = {
        sopsFile = ./secrets.yaml;
        owner = "acme";
        mode = "0400";
      };
    })

    # --- Receivers ---
    {
      users.users = builtins.listToAttrs (
        map (
          r:
          lib.nameValuePair r.user {
            isSystemUser = true;
            group = r.user;
            home = "/var/lib/acme/${r.domain}";
            shell = pkgs.bashInteractive;
            openssh.authorizedKeys.keys = [ acmeSyncPubKey ];
          }
        ) cfg.mkReceiver
      );

      users.groups = builtins.listToAttrs (
        map (
          r:
          lib.nameValuePair r.user {
            members = r.extraGroupMembers;
          }
        ) cfg.mkReceiver
      );

      systemd.tmpfiles.rules = lib.concatMap (r: [
        "d /var/lib/acme/${r.domain} 0750 ${r.user} ${r.user} - -"
      ]) cfg.mkReceiver;

      systemd.services = builtins.listToAttrs (
        map (
          r:
          lib.nameValuePair "${r.user}-reload-${r.reloadService}" {
            description = "Reload ${r.reloadService} after certificate sync for ${r.domain}";
            serviceConfig = {
              Type = "oneshot";
              ExecStart = "${pkgs.systemd}/bin/systemctl reload ${r.reloadService}";
            };
          }
        ) cfg.mkReceiver
      );

      systemd.paths = builtins.listToAttrs (
        map (
          r:
          lib.nameValuePair "${r.user}-watch" {
            wantedBy = [ "multi-user.target" ];
            pathConfig = {
              PathChanged = "/var/lib/acme/${r.domain}/fullchain.pem";
              Unit = "${r.user}-reload-${r.reloadService}.service";
            };
          }
        ) cfg.mkReceiver
      );
    }
  ];
}
