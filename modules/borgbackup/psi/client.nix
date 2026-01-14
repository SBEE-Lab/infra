{ config, ... }:
{
  services.borgbackup.jobs.psi = {
    paths = [
      "/project"
      "/blobs"
    ];
    exclude = [
      "*.pyc"
      "*/.cache/*"
      "*/.nix-profile/*"
      "*/__pycache__/*"
      "*/node_modules/*"
      ".cargo/*"
      ".direnv/*"
      ".jj/*"
      ".ruff_cache/*"
      ".terraform.lock.hcl"
      ".terraform/*"
      ".terragrunt-cache/*"
      "backend.tf"
      "target/*"
    ];
    repo = "borg@${config.networking.sbee.hosts.tau.wg-mgnt}:/backup/borg/psi";
    encryption = {
      mode = "repokey-blake2";
      passCommand = "cat ${config.sops.secrets.borg-passphrase.path}";
    };
    environment.BORG_RSH = "ssh -i ${config.sops.secrets.borg-ssh-key.path} -p 10022";
    compression = "auto,zstd,10";
    startAt = "*-*-* 03:00:00";
    persistentTimer = true;
    inhibitsSleep = true;
    prune.keep = {
      daily = 7;
      weekly = 4;
      monthly = 3;
    };
    postHook = ''
      if [ "$exitStatus" != "0" ]; then
        echo "Borgbackup failed on ${config.networking.hostName} with status $exitStatus" >&2
      fi
    '';
  };

  sops.secrets.borg-ssh-key = {
    sopsFile = ./secrets.yaml;
    mode = "0400";
  };
  sops.secrets.borg-passphrase = {
    sopsFile = ./secrets.yaml;
  };
}
