{
  services.borgbackup.repos.psi = {
    path = "/backup/borg/psi";
    authorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHCb2VqMFvFBOafvy3Vxyln5N+eZPoMRgzSBF+mGdTDt borg@psi"
    ];
  };

  systemd.services.borgbackup-repo-psi-permissions = {
    description = "Repair ownership for BorgBackup repository psi";
    after = [ "borgbackup-repo-psi.service" ];
    requires = [ "borgbackup-repo-psi.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      chown -R borg:borg /backup/borg/psi
    '';
  };
}
