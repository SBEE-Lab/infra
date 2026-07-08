{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.disko.xfsProjectQuotas;
  inherit (lib)
    concatMapStringsSep
    concatStringsSep
    escapeShellArg
    filter
    flatten
    hasPrefix
    mapAttrs'
    mapAttrsToList
    mkEnableOption
    mkIf
    mkOption
    nameValuePair
    optionalString
    types
    unique
    ;

  projectType = types.submodule {
    options = {
      id = mkOption {
        type = types.ints.positive;
        description = "Numeric XFS project quota id.";
        example = 1001;
      };

      path = mkOption {
        type = types.str;
        description = "Absolute path assigned to this XFS project quota.";
        example = "/blobs";
      };

      blockHardLimit = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Optional XFS project quota block hard limit, passed as bhard=VALUE.";
        example = "200g";
      };
    };
  };

  filesystemType = types.submodule {
    options.projects = mkOption {
      type = types.attrsOf projectType;
      default = { };
      description = "XFS project quotas declared for this mounted filesystem.";
    };
  };

  allProjects = flatten (
    mapAttrsToList (
      filesystem: filesystemCfg:
      mapAttrsToList (name: project: {
        inherit filesystem name project;
      }) filesystemCfg.projects
    ) cfg.filesystems
  );

  projectNames = map (entry: entry.name) allProjects;
  projectIds = map (entry: entry.project.id) allProjects;
  duplicateValues =
    values: filter (value: builtins.length (filter (other: other == value) values) > 1) (unique values);
  duplicateNames = duplicateValues projectNames;
  duplicateIds = duplicateValues projectIds;
  relativeFilesystems = filter (filesystem: !hasPrefix "/" filesystem) (
    builtins.attrNames cfg.filesystems
  );
  relativeProjectPaths = map (entry: "${entry.name}:${entry.project.path}") (
    filter (entry: !hasPrefix "/" entry.project.path) allProjects
  );
  emptyBlockHardLimits = map (entry: entry.name) (
    filter (entry: entry.project.blockHardLimit == "") allProjects
  );

  projectsFile = concatMapStringsSep "\n" (
    entry: "${toString entry.project.id}:${entry.project.path}"
  ) allProjects;
  projidFile = concatMapStringsSep "\n" (
    entry: "${entry.name}:${toString entry.project.id}"
  ) allProjects;

  filesystemServiceName =
    filesystem:
    if filesystem == "/" then
      "root"
    else
      lib.strings.sanitizeDerivationName (
        builtins.replaceStrings [ "/" ] [ "-" ] (lib.removePrefix "/" filesystem)
      );

  mkQuotaCommand =
    entry:
    let
      limitCommand = optionalString (entry.project.blockHardLimit != null) ''
        xfs_quota -x -c ${escapeShellArg "limit -p bhard=${entry.project.blockHardLimit} ${entry.name}"} ${escapeShellArg entry.filesystem}
      '';
    in
    ''
      xfs_quota -x -c ${escapeShellArg "project -s ${entry.name}"} ${escapeShellArg entry.filesystem}
      ${limitCommand}
      xfs_quota -x -c ${escapeShellArg "quota -p -h ${entry.name}"} ${escapeShellArg entry.filesystem}
    '';

  mkFilesystemService =
    filesystem: filesystemCfg:
    let
      entries = mapAttrsToList (name: project: {
        inherit filesystem name project;
      }) filesystemCfg.projects;
    in
    nameValuePair "xfs-project-quota-${filesystemServiceName filesystem}" {
      description = "Apply XFS project quotas on ${filesystem}";
      wantedBy = [ "multi-user.target" ];
      path = [
        pkgs.coreutils
        pkgs.findutils
        pkgs.gnugrep
        pkgs.util-linux
        pkgs.xfsprogs
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        set -euo pipefail
        test "$(findmnt -no FSTYPE ${escapeShellArg filesystem})" = xfs
        findmnt -no OPTIONS ${escapeShellArg filesystem} | grep -Eq '(^|,)(pquota|prjquota)(,|$)'
        ${concatStringsSep "\n" (map mkQuotaCommand entries)}
      '';
    };
in
{
  options.disko.xfsProjectQuotas = {
    enable = mkEnableOption "declarative XFS project quota assignment";

    filesystems = mkOption {
      type = types.attrsOf filesystemType;
      default = { };
      description = "Mounted XFS filesystems and project quotas to apply.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = duplicateNames == [ ];
        message = "disko.xfsProjectQuotas project names must be unique: ${concatStringsSep ", " duplicateNames}";
      }
      {
        assertion = duplicateIds == [ ];
        message = "disko.xfsProjectQuotas project ids must be unique: ${concatStringsSep ", " (map toString duplicateIds)}";
      }
      {
        assertion = relativeFilesystems == [ ];
        message = "disko.xfsProjectQuotas filesystem keys must be absolute paths: ${concatStringsSep ", " relativeFilesystems}";
      }
      {
        assertion = relativeProjectPaths == [ ];
        message = "disko.xfsProjectQuotas project paths must be absolute: ${concatStringsSep ", " relativeProjectPaths}";
      }
      {
        assertion = emptyBlockHardLimits == [ ];
        message = "disko.xfsProjectQuotas blockHardLimit must not be empty: ${concatStringsSep ", " emptyBlockHardLimits}";
      }
    ];

    environment.etc = {
      projects.text = optionalString (allProjects != [ ]) "${projectsFile}\n";
      projid.text = optionalString (allProjects != [ ]) "${projidFile}\n";
    };

    systemd.services = mapAttrs' mkFilesystemService cfg.filesystems;
  };
}
