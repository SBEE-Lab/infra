{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.nixbot.niks3;
  inherit (inputs.nixbot.lib) interpolate;

  routeNames = builtins.attrNames cfg.routes;
  routes = lib.mapAttrsToList (name: value: { inherit name value; }) cfg.routes;
  explicitRoutes = builtins.filter (route: !route.value.default) routes;
  defaultRoutes = builtins.filter (route: route.value.default) routes;
  explicitPatterns = lib.concatMap (route: route.value.projectPatterns) explicitRoutes;
  credentialName = name: "niks3-${name}-auth-token";

  duplicatePatterns = builtins.attrNames (
    lib.filterAttrs (_pattern: count: count > 1) (
      builtins.foldl' (
        counts: pattern: counts // { ${pattern} = (counts.${pattern} or 0) + 1; }
      ) { } explicitPatterns
    )
  );

  routeConfigFile = pkgs.writeText "nixbot-niks3-routes.json" (
    builtins.toJSON (
      lib.mapAttrs (name: route: {
        inherit (route) default;
        project_patterns = route.projectPatterns;
        server_url = route.serverUrl;
        credential_name = credentialName name;
      }) cfg.routes
    )
  );

  router = pkgs.writers.writePython3Bin "nixbot-niks3-router" { } ''
    import json
    import os
    import re
    import sys
    from pathlib import Path
    from typing import TypedDict


    class Route(TypedDict):
        default: bool
        project_patterns: list[str]
        server_url: str
        credential_name: str


    ROUTES_PATH = Path(
        "${routeConfigFile}"
    )
    ROUTES: dict[str, Route] = json.loads(ROUTES_PATH.read_text(encoding="utf-8"))
    NIKS3 = "${lib.getExe' cfg.package "niks3"}"


    def glob_match(pattern: str, value: str) -> bool:
        """Match niks3 OIDC-style * and ? wildcards."""
        parts: list[str] = []
        for character in pattern:
            if character == "*":
                parts.append(".*")
            elif character == "?":
                parts.append(".")
            else:
                parts.append(re.escape(character))
        return re.fullmatch("".join(parts), value, flags=re.DOTALL) is not None


    def resolve(project: str) -> tuple[str, Route]:
        matches: list[tuple[str, Route]] = []
        default_route: tuple[str, Route] | None = None

        for name, route in ROUTES.items():
            if route["default"]:
                default_route = (name, route)
            elif any(
                glob_match(pattern, project)
                for pattern in route["project_patterns"]
            ):
                matches.append((name, route))

        if len(matches) > 1:
            names = ", ".join(name for name, _route in matches)
            raise ValueError(
                f"Project {project} matches multiple niks3 routes: {names}"
            )
        if matches:
            return matches[0]
        if default_route is None:
            raise ValueError("No default niks3 route configured")
        return default_route


    def main() -> int:
        arguments = sys.argv[1:]
        resolve_only = bool(arguments and arguments[0] == "--resolve")
        if resolve_only:
            arguments = arguments[1:]

        expected_arguments = 1 if resolve_only else 2
        if len(arguments) != expected_arguments:
            print(
                "usage: nixbot-niks3-router [--resolve] PROJECT [OUT_LINK]",
                file=sys.stderr,
            )
            return 2

        project = arguments[0]
        try:
            route_name, route = resolve(project)
        except ValueError as error:
            print(error, file=sys.stderr)
            return 1

        credential_name = route["credential_name"]
        server_url = route["server_url"]
        if resolve_only:
            print(f"{route_name}\t{server_url}\t{credential_name}")
            return 0

        credentials_directory = os.environ.get("CREDENTIALS_DIRECTORY")
        if credentials_directory is None:
            print("CREDENTIALS_DIRECTORY is not set", file=sys.stderr)
            return 1

        print(f"Pushing {project} to {server_url}", flush=True)
        environment = os.environ.copy()
        environment["NIKS3_SERVER_URL"] = server_url
        environment["NIKS3_AUTH_TOKEN_FILE"] = str(
            Path(credentials_directory) / credential_name
        )
        os.execve(NIKS3, [NIKS3, "push", arguments[1]], environment)


    if __name__ == "__main__":
        sys.exit(main())
  '';

  routeModule = lib.types.submodule {
    options = {
      projectPatterns = lib.mkOption {
        type = lib.types.listOf (lib.types.strMatching ".+");
        default = [ ];
        description = "Nixbot owner/repository names routed to this cache, using niks3 OIDC-style * and ? wildcards.";
        example = [ "myorg/*" ];
      };

      default = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether this route receives repositories not matched by an explicit route.";
      };

      serverUrl = lib.mkOption {
        type = lib.types.strMatching "https://.+";
        description = "niks3 server URL for this route.";
      };

      authTokenFile = lib.mkOption {
        type = lib.types.path;
        description = "File containing this route's niks3 API token.";
      };
    };
  };
in
{
  # Replace nixbot's single-endpoint integration while retaining the rest of
  # its NixOS module. Input updates fail evaluation if this internal path moves.
  disabledModules = [ "${inputs.nixbot}/nixosModules/niks3.nix" ];

  options.services.nixbot.niks3 = {
    enable = lib.mkEnableOption "repository-aware niks3 integration";

    package = lib.mkOption {
      type = lib.types.package;
      default = inputs.niks3.packages.${pkgs.stdenv.hostPlatform.system}.default;
      defaultText = lib.literalExpression "inputs.niks3.packages.\${system}.default";
      description = "niks3 CLI package used for uploads.";
    };

    routes = lib.mkOption {
      type = lib.types.attrsOf routeModule;
      default = { };
      description = "Named, mutually exclusive cache routes.";
    };

  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = routeNames != [ ];
        message = "services.nixbot.niks3.routes must define at least one route";
      }
      {
        assertion = builtins.length defaultRoutes == 1;
        message = "services.nixbot.niks3.routes must define exactly one default route";
      }
      {
        assertion = builtins.all (route: !route.value.default || route.value.projectPatterns == [ ]) routes;
        message = "services.nixbot.niks3 default route cannot define projectPatterns";
      }
      {
        assertion = builtins.all (route: route.value.default || route.value.projectPatterns != [ ]) routes;
        message = "services.nixbot.niks3 explicit routes must define at least one project pattern";
      }
      {
        assertion = duplicatePatterns == [ ];
        message = "services.nixbot.niks3 project patterns must belong to one route: ${lib.concatStringsSep ", " duplicatePatterns}";
      }
      {
        assertion = builtins.all (name: builtins.match "[A-Za-z0-9_.-]+" name != null) routeNames;
        message = "services.nixbot.niks3 route names must be safe systemd credential identifiers";
      }
    ];

    services.nixbot.postBuildSteps = [
      {
        name = "Route build to niks3";
        command = [
          (lib.getExe router)
          (interpolate "%(prop:project)s")
          (interpolate "%(prop:out_link)s")
        ];
        warnOnly = true;
      }
    ];

    systemd.services.nixbot.serviceConfig.LoadCredential = lib.mapAttrsToList (
      name: route: "${credentialName name}:${toString route.authTokenFile}"
    ) cfg.routes;
  };
}
