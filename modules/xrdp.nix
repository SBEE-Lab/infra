# https://github.com/TUM-DSE/doctor-cluster-config/tree/4702b65ba00ccaf932fa87c71eee5a5b584896ab/modules/xrdp.nix
{ pkgs, ... }:
{
  networking.firewall.allowedTCPPorts = [ 3389 ];
  services.xrdp.enable = true;
  # FIXME: this is actually ignored with the latest xrdp
  services.xrdp.defaultWindowManager = "${pkgs.xfce.xfce4-session}/bin/xfce4-session";

  services.xserver = {
    enable = true;
    desktopManager.xfce.enable = true;
    xkb.layout = "us";
    xkb.variant = "altgr-intl";
  };
  fonts.fontconfig.enable = true;
  fonts.enableDefaultPackages = true;

  environment.etc."xrdp/startwm.sh" = {
    text = ''
      ${pkgs.runtimeShell}
      . /etc/profile
      ${pkgs.xfce.xfce4-session}/bin/xfce4-session
    '';
    mode = "755";
  };
}
