# Buildbot PostgreSQL database (deployed on rho)
{
  config,
  lib,
  ...
}:
let
  inherit (config.networking.sbee) hosts;
  psql = "${config.services.postgresql.package}/bin/psql --port=${toString config.services.postgresql.settings.port}";
in
{
  services.postgresql = {
    # wg-admin already set in postgresql/default.nix
    ensureDatabases = [ "buildbot" ];
    ensureUsers = [
      {
        name = "buildbot";
        ensureDBOwnership = true;
      }
    ];
    authentication = lib.mkAfter ''
      host buildbot buildbot ${hosts.psi.wg-admin}/32 scram-sha-256
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

  # PostgreSQL port already opened on wg-admin in postgresql/default.nix
}
