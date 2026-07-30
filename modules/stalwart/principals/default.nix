{
  config,
  pkgs,
  ...
}:
let
  httpPort = 8082;
  desiredPrincipals = pkgs.writeText "stalwart-principals.json" (
    builtins.toJSON (import ./principals.nix)
  );
in
{
  systemd.services.stalwart-ensure-principals = {
    description = "Reconcile declarative Stalwart principals";
    wantedBy = [ "multi-user.target" ];
    after = [ "stalwart.service" ];
    requires = [ "stalwart.service" ];
    restartTriggers = [ desiredPrincipals ];
    serviceConfig = {
      Type = "oneshot";
      User = "stalwart-mail";
      Group = "stalwart-mail";
      LoadCredential = [
        "admin-password:${config.sops.secrets.stalwart-admin-password.path}"
      ];
      ExecStart = ''
        ${pkgs.python3}/bin/python3 ${./ensure_principals.py} \
          --api-url http://127.0.0.1:${toString httpPort}/api \
          --admin-password-file %d/admin-password \
          --desired ${desiredPrincipals}
      '';
    };
  };
}
