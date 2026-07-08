{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.rustfs;
  endpoint = "http://${cfg.listenAddress}:${toString cfg.apiPort}";
  bucketNames = map (bucket: bucket.name) cfg.ensureBuckets;
  userNames = map (user: user.name) cfg.ensureUsers;
  declaredPolicyNames = lib.attrNames cfg.ensurePolicies;
  attachedPolicyNames = lib.flatten (map (user: user.policies) cfg.ensureUsers);
  emptyPolicyNames = lib.attrNames (
    lib.filterAttrs (_: policy: policy.statements == [ ]) cfg.ensurePolicies
  );
  usersWithoutPolicies = map (user: user.name) (
    lib.filter (user: user.policies == [ ]) cfg.ensureUsers
  );
  hasBootstrapState = cfg.ensureBuckets != [ ] || cfg.ensurePolicies != { } || cfg.ensureUsers != [ ];
  mkPolicyDocument = policy: {
    Version = "2012-10-17";
    Statement = map (
      statement:
      {
        Effect = statement.effect;
        Action = statement.actions;
        Resource = statement.resources;
      }
      // lib.optionalAttrs (statement.condition != null) {
        Condition = statement.condition;
      }
    ) policy.statements;
  };
  policyFiles = lib.mapAttrs (
    name: policy:
    pkgs.writeText "rustfs-policy-${name}.json" (builtins.toJSON (mkPolicyDocument policy))
  ) cfg.ensurePolicies;
  rustfsBootstrapScript = pkgs.writeShellApplication {
    name = "rustfs-bootstrap";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.getent
      pkgs.gnugrep
      pkgs.minio-client
    ];
    text = ''
      set -euo pipefail

      access_key_file=${lib.escapeShellArg cfg.rootAccessKeyFile}
      secret_key_file=${lib.escapeShellArg cfg.rootSecretKeyFile}

      # systemd provides RUNTIME_DIRECTORY for services with RuntimeDirectory=.
      # shellcheck disable=SC2154
      export MC_CONFIG_DIR="''${RUNTIME_DIRECTORY:?}/mc"
      export MC_QUIET=true
      export MC_NO_COLOR=true

      root_access_key=$(<"$access_key_file")
      root_secret_key=$(<"$secret_key_file")

      curl --fail --silent --show-error \
        --retry 30 \
        --retry-delay 2 \
        --retry-connrefused \
        ${lib.escapeShellArg "${endpoint}/health/ready"} >/dev/null

      mc alias set rustfs-local ${lib.escapeShellArg endpoint} "$root_access_key" "$root_secret_key" --api S3v4 >/dev/null

      ${lib.concatMapStringsSep "\n" (bucket: ''
        mc mb --ignore-existing ${lib.escapeShellArg "rustfs-local/${bucket.name}"} >/dev/null
        ${lib.optionalString bucket.versioning ''
          mc version enable ${lib.escapeShellArg "rustfs-local/${bucket.name}"} >/dev/null

          if ! mc version info ${lib.escapeShellArg "rustfs-local/${bucket.name}"} | grep -q "versioning is enabled"; then
            echo ${lib.escapeShellArg "RustFS bucket ${bucket.name} does not report enabled versioning"} >&2
            exit 1
          fi
        ''}
      '') cfg.ensureBuckets}

      ${lib.concatStringsSep "\n" (
        lib.mapAttrsToList (name: _policy: ''
          mc admin policy create rustfs-local ${lib.escapeShellArg name} ${
            lib.escapeShellArg policyFiles.${name}
          } >/dev/null
        '') cfg.ensurePolicies
      )}

      ${lib.concatMapStringsSep "\n" (user: ''
        user_secret_key=$(<${lib.escapeShellArg user.secretKeyFile})
        printf '%s\n%s\n' ${lib.escapeShellArg user.name} "$user_secret_key" | mc admin user add rustfs-local >/dev/null
        ${lib.optionalString (user.policies != [ ]) ''
          mc admin policy attach rustfs-local ${lib.escapeShellArgs user.policies} --user ${lib.escapeShellArg user.name} >/dev/null
        ''}
      '') cfg.ensureUsers}
    '';
  };
in
{
  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = lib.unique bucketNames == bucketNames;
            message = "services.rustfs.ensureBuckets contains duplicate bucket names";
          }
          {
            assertion = lib.unique userNames == userNames;
            message = "services.rustfs.ensureUsers contains duplicate user names";
          }
          {
            assertion = lib.all (policy: lib.elem policy declaredPolicyNames) attachedPolicyNames;
            message = "services.rustfs.ensureUsers references a policy that is not declared in services.rustfs.ensurePolicies";
          }
          {
            assertion = emptyPolicyNames == [ ];
            message = "services.rustfs.ensurePolicies must not declare policies with empty statements: ${lib.concatStringsSep ", " emptyPolicyNames}";
          }
          {
            assertion = usersWithoutPolicies == [ ];
            message = "services.rustfs.ensureUsers must not declare users without policies: ${lib.concatStringsSep ", " usersWithoutPolicies}";
          }
        ];
      }

      (lib.mkIf hasBootstrapState {
        systemd.services.rustfs-bootstrap = {
          description = "Bootstrap RustFS buckets and IAM";
          wantedBy = [ "multi-user.target" ];
          after = [
            "network-online.target"
            "rustfs.service"
          ]
          ++ lib.optional (cfg.secretInstallService != null) cfg.secretInstallService;
          wants = [ "network-online.target" ];
          requires = [
            "rustfs.service"
          ]
          ++ lib.optional (cfg.secretInstallService != null) cfg.secretInstallService;

          serviceConfig = {
            Type = "oneshot";
            RuntimeDirectory = "rustfs-bootstrap";
            RuntimeDirectoryMode = "0700";
            ExecStart = "${rustfsBootstrapScript}/bin/rustfs-bootstrap";
          };
        };
      })
    ]
  );
}
