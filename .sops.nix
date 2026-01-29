# https://github.com/TUM-DSE/doctor-cluster-config/tree/4702b65ba00ccaf932fa87c71eee5a5b584896ab/sops.yaml.nix
# IMPORTANT when changing this file, also run
# $ inv update-sops-files
# to update .sops.yaml:
let
  mapAttrsToList = f: attrs: map (name: f name attrs.${name}) (builtins.attrNames attrs);

  renderPermissions =
    attrs:
    mapAttrsToList (path: keys: {
      path_regex = path;
      key_groups = [ { age = keys ++ groups.admin; } ];
    }) attrs;

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
        value = [ key ];
      }) keys.machines
    )
    // builtins.mapAttrs (_name: value: (map (x: keys.machines.${x}) value)) {
      "modules/acme/secrets.yaml" = [
        "eta"
        "tau"
      ];
      "modules/attic/secrets.yaml" = [ "eta" ];
      "modules/authentik/secrets.yaml" = [ "eta" ];
      "modules/headscale/secrets.yaml" = [ "eta" ];
      "modules/tailscale/secrets.yaml" = [
        "psi"
        "rho"
        "tau"
      ];
      "modules/borgbackup/psi/secrets.yaml" = [ "psi" ];
      "modules/borgbackup/rho/secrets.yaml" = [ "rho" ];
      "modules/buildbot/secrets.yaml" = [
        "psi"
        "rho"
      ];
      "modules/harmonia/secrets.yaml" = [ "psi" ];
      "modules/monitoring/secrets.yaml" = [ "rho" ];
      "modules/nextcloud/secrets.yaml" = [ "tau" ];
      "modules/nfs/secrets.yaml" = [ "psi" ];
      "modules/users/xrdp-passwords.yaml" = [ "psi" ];
      "terraform/cloudflare/secrets.yaml" = [ ];
      "terraform/github/secrets.yaml" = [ ];
      "terraform/vultr/secrets.yaml" = [ ];
    }
    // {
      "modules/sshd/[^/]+\\.yaml$" = [ ];
      "terraform/secrets.yaml" = [ ];
      "^\\.secrets\\.yaml$" = [ ];
    };
in
{
  creation_rules = renderPermissions sopsPermissions;
}
