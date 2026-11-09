{ self, ... }:
{
  perSystem =
    {
      pkgs,
      lib,
      ...
    }:
    {
      packages = {
        docker-auth = pkgs.callPackage ./docker_auth { };
        infra-alert-bridge = pkgs.callPackage ./infra-alert-bridge { };
        slack-cli = pkgs.callPackage ./slack-cli { buildGoModule = pkgs.buildGo127Module; };
        slack-group-sync = pkgs.callPackage ./slack-group-sync { };
        updater = pkgs.callPackage ./updater { };
        zui = pkgs.callPackage ./zui { };
      }
      // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        installer = pkgs.callPackage ./image-installer { inherit pkgs self; };
      };
    };
}
