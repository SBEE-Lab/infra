{ lib, pkgs }:
let
  fonts = with pkgs; [
    nanum
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
  ];
  cache = pkgs.makeFontsCache {
    fontDirectories = fonts;
  };
  file = pkgs.writeText "collabora-fonts.conf" ''
    <?xml version="1.0"?>
    <fontconfig>
      ${lib.concatMapStringsSep "\n" (font: "<dir>${font}</dir>") fonts}
      <cachedir>${cache}</cachedir>
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
  inherit cache file fonts;
}
