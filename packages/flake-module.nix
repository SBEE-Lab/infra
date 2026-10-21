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
        updater = pkgs.callPackage ./updater { };
      }
      // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        installer = pkgs.callPackage ./image-installer { inherit pkgs self; };
        kexec = pkgs.callPackage ./kexec-installer { inherit pkgs self; };
        neko-image = pkgs.callPackage ./neko-image { };
      };
    };
}
