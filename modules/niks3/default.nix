{
  config,
  inputs,
  ...
}:
let
  inherit (config.networking.sbee) hosts;
  secretsFile = ./secrets.yaml;
in
{
  imports = [
    inputs.niks3.nixosModules.niks3
    ../gatus/check.nix
  ];

  services.niks3 = {
    enable = true;
    httpAddr = "${hosts.psi.wg-admin}:5751";

    s3 = {
      endpoint = "0572d3fa726276fa78f433d5ba90048e.r2.cloudflarestorage.com";
      bucket = "niks3";
      region = "auto";
      bucketLookup = "path";
      accessKeyFile = config.sops.secrets.niks3-r2-access-key-id.path;
      secretKeyFile = config.sops.secrets.niks3-r2-secret-access-key.path;
    };

    apiTokenFile = config.sops.secrets.niks3-auth-token.path;
    signKeyFiles = [ config.sops.secrets.niks3-signing-key.path ];
    cacheUrl = "https://cache.sjanglab.org";
    serverUrl = "https://niks3.sjanglab.org";

    gc = {
      olderThan = "720h";
      failedUploadsOlderThan = "6h";
      schedule = "*-*-* 04:00:00";
    };
  };

  sops.secrets = {
    niks3-r2-access-key-id = {
      sopsFile = secretsFile;
      owner = "niks3";
    };
    niks3-r2-secret-access-key = {
      sopsFile = secretsFile;
      owner = "niks3";
    };
    niks3-signing-key = {
      sopsFile = secretsFile;
      owner = "niks3";
    };
  };

  gatusCheck.push = [
    {
      name = "niks3";
      group = "cache";
      systemdService = "niks3.service";
    }
  ];

  networking.firewall.interfaces.wg-admin.allowedTCPPorts = [ 5751 ];
}
