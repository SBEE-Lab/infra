# https://github.com/TUM-DSE/doctor-cluster-config/tree/4702b65ba00ccaf932fa87c71eee5a5b584896ab/sops.yaml.nix
# IMPORTANT when changing this file, also run
# $ inv update-sops-files
# to update .sops.yaml:
let
  mapAttrsToList = f: attrs: map (name: f name attrs.${name}) (builtins.attrNames attrs);

  renderPermissions = attrs:
    mapAttrsToList (path: keys: {
      path_regex = path;
      key_groups = [{age = keys ++ groups.admin;}];
    })
    attrs;

  # command to add a new age key for a new host
  # inv print-age-key --hosts "host1,host2"
  keys = builtins.fromJSON (builtins.readFile ./pubkeys.json);
  groups = with keys.users; {
    admin = [
      # admins may access all secrets
      seungwon
    ];
    all = builtins.attrValues (keys.users // keys.machines);
  };

  # This is the list of permissions per file. The admin group has permissions
  # for all files. amy.yml additionally can be decrypted by amy.
  sopsPermissions =
    # === secrets for each machines ===
    builtins.listToAttrs (
      mapAttrsToList (hostname: key: {
        name = "hosts/${hostname}.yaml$";
        value = [key];
      })
      keys.machines
    )
    // builtins.mapAttrs (_name: value: (map (x: keys.machines.${x}) value)) {
      "modules/nfs/secrets.yaml" = ["psi"];
      "modules/users/xrdp-passwords.yaml" = ["psi"];
      "modules/acme/secrets.yaml" = [
        "eta"
      ];
      "modules/minio/secrets.yaml" = [
        "tau"
        "rho"
      ];
      # identical with modules/minio/secrets.yaml
      "terraform/minio/secrets.yaml" = [
        "tau"
        "rho"
      ];
      "terraform/cloudflare/secrets.yaml" = ["eta"];
      "terraform/github/secrets.yaml" = [];
      "terraform/vultr/secrets.yaml" = [];
      "terraform/test-machine/secrets.yaml" = [];
    }
    // {
      "modules/sshd/[^/]+\\.yaml$" = [];
      "terraform/secrets.yaml" = [];
    };
in {
  creation_rules = renderPermissions sopsPermissions;
}
