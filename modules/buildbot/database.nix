# Nixbot PostgreSQL database health/backup helpers (deployed on psi)
{
  lib,
  pkgs,
  ...
}:
{
  imports = [ ../gatus/check.nix ];

  gatusCheck.push = [
    {
      name = "Nixbot PostgreSQL";
      group = "ci";
      systemdService = "postgresql.service";
    }
  ];

  # services.nixbot provisions the nixbot database and peer-authenticated user.
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_17;

    settings = {
      listen_addresses = lib.mkForce "localhost";
      port = 5432;
    };
  };

  services.postgresqlBackup.databases = lib.mkAfter [ "nixbot" ];
}
