{
  lib,
  dockerTools,
  fetchFromGitHub,
  buildGoModule,
  buildNpmPackage,
  pkg-config,
  gtk3,
  libx11,
  libxrandr,
  libxtst,
  libxfixes,
  libxi,
  libxcvt,
  gst_all_1,
  makeWrapper,
  runCommand,
}:
let
  revision = "c7201ebace61ac7d223601cca5c42807940a3d27";
  version = "3.1.5-unstable-${builtins.substring 0 12 revision}";
  src = fetchFromGitHub {
    owner = "mulatta";
    repo = "neko";
    rev = revision;
    hash = "sha256-mP+8CnuaB0b+4xifptkXG0Irpn4i9pciTCiz+26k9Mg=";
  };
  # Keep Chromium, Xorg, PulseAudio, and their runtime configuration unchanged.
  base = dockerTools.pullImage {
    imageName = "ghcr.io/m1k1o/neko/chromium";
    imageDigest = "sha256:a79093411aced75b3ed7110d50ec9082f9933afabd6592254f01c383678082e7";
    hash = "sha256-sZ3Z0Ti/PYXP7Qqxbm6w+09Asfld4uQxnUai+62Q/tM=";
    finalImageTag = "3.1.5";
    os = "linux";
    arch = "amd64";
  };
  gstPlugins = with gst_all_1; [
    gstreamer
    gst-plugins-base
    gst-plugins-good
    gst-plugins-bad
    gst-plugins-ugly
    gst-libav
  ];
  gstPluginPath = lib.makeSearchPath "lib/gstreamer-1.0" (map lib.getLib gstPlugins);
  gstPluginScanner = "${lib.getLib gst_all_1.gstreamer}/libexec/gstreamer-1.0/gst-plugin-scanner";
  server = buildGoModule {
    pname = "neko-server";
    inherit version src;
    modRoot = "server";
    vendorHash = "sha256-LjCVw5dgfesyTUnPS77RO0m2Qk4ahJasmNOHmFQkVKE=";
    subPackages = [ "cmd/neko" ];
    nativeBuildInputs = [
      pkg-config
      makeWrapper
    ];
    buildInputs = [
      gtk3
      libx11
      libxrandr
      libxtst
      libxfixes
      libxi
      libxcvt
      gst_all_1.gstreamer
      gst_all_1.gst-plugins-base
    ];
    ldflags = [
      "-s"
      "-w"
      "-X=github.com/m1k1o/neko/server.gitCommit=${revision}"
      "-X=github.com/m1k1o/neko/server.gitBranch=master"
    ];
    checkPhase = ''
      runHook preCheck
      go test ./internal/member/oauth ./internal/api ./internal/config
      runHook postCheck
    '';
    doInstallCheck = true;
    installCheckPhase = ''
      runHook preInstallCheck
      $out/bin/neko --version | grep -F '${revision}'
      $out/bin/neko serve --help | grep -F -- '--member.oauth.client_id'
      runHook postInstallCheck
    '';
    # Do not mix Debian GStreamer plugins with the Nix-linked server libraries.
    postInstall = ''
      wrapProgram $out/bin/neko \
        --set GST_PLUGIN_SYSTEM_PATH_1_0 "${gstPluginPath}" \
        --set GST_PLUGIN_SCANNER "${gstPluginScanner}" \
        --set GST_PLUGIN_SCANNER_1_0 "${gstPluginScanner}"
    '';
  };
  client = buildNpmPackage {
    pname = "neko-client";
    inherit version src;
    sourceRoot = "source/client";
    npmDepsHash = "sha256-L8/ToH05+mIAS9+cTMQ3tWMDkyJ/4LeiAU1ywbie9a4=";
    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r dist/. $out/
      runHook postInstall
    '';
  };
  root = runCommand "neko-oauth-root" { } ''
    mkdir -p $out/usr/bin $out/var/www
    ln -s ${server}/bin/neko $out/usr/bin/neko
    cp -r ${client}/. $out/var/www/
  '';
in
# Both server and client must come from the OAuth-capable revision.
dockerTools.buildLayeredImage {
  name = "ghcr.io/m1k1o/neko/chromium";
  tag = version;
  fromImage = base;
  contents = [ root ];
  # dockerTools inherits only Env from the base image, not its startup command.
  config = {
    Cmd = [
      "/usr/bin/supervisord"
      "-c"
      "/etc/neko/supervisord.conf"
    ];
    Healthcheck = {
      Test = [
        "CMD-SHELL"
        "for i in $(seq 1 15); do wget -O - http://localhost:\${NEKO_SERVER_BIND#*:}/health && exit 0; sleep 1; done; exit 1"
      ];
      Interval = 10000000000;
      Timeout = 20000000000;
      Retries = 8;
    };
    Labels = {
      "net.m1k1o.neko.api-version" = "3";
      "org.opencontainers.image.revision" = revision;
      "org.opencontainers.image.source" = "https://github.com/m1k1o/neko";
      "org.opencontainers.image.version" = version;
    };
  };
  passthru = { inherit server client; };
}
