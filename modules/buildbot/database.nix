# Buildbot PostgreSQL database (deployed on rho)
{
  config,
  lib,
  ...
}:
let
  inherit (config.networking.sbee) currentHost hosts;
  psql = "${config.services.postgresql.package}/bin/psql --port=${toString config.services.postgresql.settings.port}";
in
{
  services.postgresql = {
    settings.listen_addresses = lib.mkForce "${currentHost.wg-mgnt},${currentHost.wg-serv}";
    ensureDatabases = [ "buildbot" ];
    ensureUsers = [
      {
        name = "buildbot";
        ensureDBOwnership = true;
      }
    ];
    authentication = lib.mkAfter ''
      host buildbot buildbot ${hosts.psi.wg-serv}/32 scram-sha-256
    '';
  };

  systemd.services.postgresql.postStart = lib.mkAfter ''
    BUILDBOT_PW=$(cat ${config.sops.secrets.buildbot-db-password.path})
    ${psql} -tAc "ALTER USER buildbot WITH PASSWORD '$BUILDBOT_PW'" -d postgres
  '';

  sops.secrets.buildbot-db-password = {
    sopsFile = ./secrets.yaml;
    owner = "postgres";
    group = "postgres";
  };

  services.postgresqlBackup.databases = lib.mkAfter [ "buildbot" ];

  networking.firewall.interfaces.wg-serv.allowedTCPPorts = [ 5432 ];
}
