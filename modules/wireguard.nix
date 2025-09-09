{
  config,
  lib,
  ...
}:
let
  getUserPubKey = lib.mapAttrsToList (_name: user: user.openssh.authorizedKeys.keys or [ ]);
in
{
  # wireguard for management network
  systemd.network.netdevs."wg0" = {
    netdevConfig = {
      Name = "wg0";
      Kind = "wireguard";
    };

    wireguardConfig = {
      PrivateKeyFile = "/etc/wireguard/secret.key";
      ListenPort = 51820;
    };

    wireguardPeers = [
      lib.genAttrs
      (getUserPubKey config.users.users)
      (pubKey: ip: {
        PublicKey = pubKey;
        AllowedIPs = ip;
      })
    ];
  };

  systemd.network.networks."wg0" = {
    matchConfig.Name = "wg0";
    networkConfig.Address = [ "10.100.0.1/24" ];
  };
}
