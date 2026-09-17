{
  config,
  lib,
  pkgs,
  ...
}:
let
  richdocuments = config.services.nextcloud.package.packages.apps.richdocuments;
  collaboraLibreOffice = config.services.collabora-online.package.libreoffice;
  fontConfig = import ./font-config.nix { inherit lib pkgs; };
  koreanSpreadsheetTemplate =
    pkgs.runCommand "nextcloud-korean-spreadsheet-template.ots"
      {
        nativeBuildInputs = [ pkgs.python3 ];
      }
      ''
        cp ${richdocuments}/emptyTemplates/template.xlsx template.xlsx
        python -c '
        from pathlib import Path
        from zipfile import ZipFile

        source = Path("template.xlsx")
        output = Path("template-patched.xlsx")
        old_font = b"<name val=\"Arial\"/>"
        new_font = b"<name val=\"Malgun Gothic\"/>"

        with ZipFile(source) as source_archive, ZipFile(output, "w") as output_archive:
            for entry in source_archive.infolist():
                content = source_archive.read(entry.filename)
                if entry.filename == "xl/styles.xml":
                    count = content.count(old_font)
                    if count != 4:
                        raise RuntimeError(f"expected 4 Arial font entries, found {count}")
                    content = content.replace(old_font, new_font)
                output_archive.writestr(entry, content)
        '

        mkdir cache home output profile
        HOME=$PWD/home \
          XDG_CACHE_HOME=$PWD/cache \
          FONTCONFIG_FILE=${fontConfig.file} \
          ${collaboraLibreOffice}/lib/collaboraoffice/program/soffice \
          --headless \
          -env:UserInstallation=file://$PWD/profile \
          --convert-to ots \
          --outdir output \
          template-patched.xlsx
        cp output/template-patched.ots $out

        OUTPUT_TEMPLATE=$out python -c '
        import os
        from pathlib import Path
        from zipfile import ZipFile

        output = Path(os.environ["OUTPUT_TEMPLATE"])
        with ZipFile(output) as archive:
            if archive.testzip() is not None:
                raise RuntimeError("generated spreadsheet template failed ZIP validation")
            styles = archive.read("styles.xml")
            if b"Malgun Gothic" not in styles:
                raise RuntimeError("generated spreadsheet template lacks Malgun Gothic style")
        '
      '';
in
{
  systemd.services.nextcloud-korean-spreadsheet-template = {
    description = "Install Korean spreadsheet template for Nextcloud Office";
    wantedBy = [ "multi-user.target" ];
    requires = [ "nextcloud-setup.service" ];
    after = [ "nextcloud-setup.service" ];
    restartTriggers = [ koreanSpreadsheetTemplate ];
    path = [
      pkgs.diffutils
      pkgs.findutils
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -euo pipefail

      occ=${lib.getExe config.services.nextcloud.occ}
      instance_id="$($occ config:system:get instanceid)"
      template_dir=${config.services.nextcloud.datadir}/data/appdata_"$instance_id"/richdocuments/empty_templates

      if [[ ! -d "$template_dir" ]] || [[ -z "$(find "$template_dir" -mindepth 1 -maxdepth 1 -type f -print -quit)" ]]; then
        $occ richdocuments:update-empty-templates
      fi

      if ! cmp --silent ${koreanSpreadsheetTemplate} "$template_dir/spreadsheet.ots"; then
        install --owner=nextcloud --group=nextcloud --mode=0640 \
          ${koreanSpreadsheetTemplate} "$template_dir/spreadsheet.ots"
        $occ files:scan-app-data richdocuments/empty_templates
      fi
    '';
  };
}
