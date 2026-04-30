# Buildbot PostgreSQL database (deployed on psi)
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.networking.sbee) hosts;
  psql = "${config.services.postgresql.package}/bin/psql --port=${toString config.services.postgresql.settings.port}";
in
{
  imports = [ ../gatus/check.nix ];

  gatusCheck.push = [
    {
      name = "Buildbot PostgreSQL";
      group = "ci";
      systemdService = "postgresql.service";
    }
  ];

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_17;

    settings = {
      listen_addresses = lib.mkForce hosts.psi.wg-admin;
      port = 5432;
    };

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

  networking.firewall.interfaces.wg-admin.allowedTCPPorts = [ 5432 ];
}
