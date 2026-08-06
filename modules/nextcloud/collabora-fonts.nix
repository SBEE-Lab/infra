{ lib, pkgs, ... }:
let
  koreanOfficeFonts = with pkgs; [
    nanum
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
  ];
  collaboraFontCache = pkgs.makeFontsCache {
    fontDirectories = koreanOfficeFonts;
  };
  collaboraFontconfig = pkgs.writeText "collabora-fonts.conf" ''
    <?xml version="1.0"?>
    <fontconfig>
      ${lib.concatMapStringsSep "\n" (font: "<dir>${font}</dir>") koreanOfficeFonts}
      <cachedir>${collaboraFontCache}</cachedir>
      <cachedir>/tmp/fontconfig-cache</cachedir>
      <alias><family>Malgun Gothic</family><prefer><family>Noto Sans CJK KR</family></prefer></alias>
      <alias><family>맑은 고딕</family><prefer><family>Noto Sans CJK KR</family></prefer></alias>
      <alias><family>Gulim</family><prefer><family>NanumGothic</family></prefer></alias>
      <alias><family>굴림</family><prefer><family>NanumGothic</family></prefer></alias>
      <alias><family>Dotum</family><prefer><family>NanumGothic</family></prefer></alias>
      <alias><family>돋움</family><prefer><family>NanumGothic</family></prefer></alias>
      <alias><family>Batang</family><prefer><family>Noto Serif CJK KR</family></prefer></alias>
      <alias><family>바탕</family><prefer><family>Noto Serif CJK KR</family></prefer></alias>
    </fontconfig>
  '';
in
{
  systemd.services = {
    coolwsd-systemplate-setup.path = [ pkgs.cpio ];

    coolwsd = {
      environment.FONTCONFIG_FILE = collaboraFontconfig;
      restartTriggers = [ collaboraFontconfig ];
    };
  };
}
