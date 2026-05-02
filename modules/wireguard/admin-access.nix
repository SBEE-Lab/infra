{ config, lib, ... }:
let
  cfg = config.networking.sbee;

  adminPeers = cfg.adminWireguardPeers;
  adminUsers = lib.filterAttrs (
    _name: user: user.isNormalUser && builtins.elem "admin" user.extraGroups
  ) config.users.users;
  adminUserNames = builtins.attrNames adminUsers;
  peerOwners = lib.mapAttrsToList (_name: peer: peer.owner) adminPeers;
  peerAddresses = lib.mapAttrsToList (_name: peer: peer.address) adminPeers;
  machineWgAddresses = lib.filter (addr: addr != null) (
    lib.mapAttrsToList (_name: host: host.wg-admin) cfg.hosts
  );
in
{
  options.networking.sbee.adminWireguardPeers = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          owner = lib.mkOption {
            type = lib.types.str;
            description = "Admin user that owns this WireGuard peer.";
          };
          address = lib.mkOption {
            type = lib.types.str;
            description = "Unique wg-admin IPv4 address without CIDR.";
          };
          publicKey = lib.mkOption {
            type = lib.types.str;
            description = "WireGuard public key for the admin-owned device.";
          };
        };
      }
    );
    default = { };
    description = "Admin-owned WireGuard peers allowed on the wg-admin network.";
  };

  config = {
    networking.sbee.adminWireguardPeers = {
      seungwon-rhesus = {
        owner = "seungwon";
        address = "10.100.0.200";
        publicKey = "EeRAyghu9jCEIwiuVEXtkfi9WrEyr+TuqnCgIHktGWg=";
      };
    };

    networking.sbee.wireguard.wg-admin.peers = lib.mapAttrsToList (_name: peer: {
      PublicKey = peer.publicKey;
      AllowedIPs = [ "${peer.address}/32" ];
    }) adminPeers;

    assertions = [
      {
        assertion = lib.all (name: builtins.elem name peerOwners) adminUserNames;
        message = "Every admin user must own at least one networking.sbee.adminWireguardPeers entry.";
      }
      {
        assertion = lib.all (owner: builtins.hasAttr owner adminUsers) peerOwners;
        message = "Every admin WireGuard peer owner must be an admin user.";
      }
      {
        assertion = (builtins.length peerAddresses) == (builtins.length (lib.unique peerAddresses));
        message = "Admin WireGuard peer addresses must be unique.";
      }
      {
        assertion = lib.all (address: !(builtins.elem address machineWgAddresses)) peerAddresses;
        message = "Admin WireGuard peer addresses must not overlap machine wg-admin addresses.";
      }
    ];
  };
}
