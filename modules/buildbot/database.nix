# Nixbot database health/backup helpers (deployed on psi)
{
  lib,
  pkgs,
  ...
}:
{
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
