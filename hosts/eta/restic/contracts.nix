let
  mkContract = name: rec {
    repository = "eta-${name}";
    endpoint = "https://0572d3fa726276fa78f433d5ba90048e.r2.cloudflarestorage.com";
    bucket = "eta-restic-backups";
    prefix = "eta/${name}";
    secretNames.repositoryPassword = "${repository}-repository-password";
  };
in
{
  postgresql = mkContract "postgresql";
  vaultwarden = mkContract "vaultwarden";
}
