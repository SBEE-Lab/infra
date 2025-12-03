{
  services.borgbackup.repos.rho = {
    path = "/backup/borg/rho";
    authorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAWoiIAXYfS4U26NISKauk0o9wCErVYh7AP82OQIWVxd borg@rho"
    ];
  };
}
