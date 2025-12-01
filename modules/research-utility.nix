{pkgs, ...}: {
  programs.singularity = {
    enable = true;
    package = pkgs.apptainer;
  };

  environment.systemPackages = with pkgs; [
    blast
    nextflow
    stdenv.cc.cc.lib
    zlib
    libGL
    gcc
    pkg-config
    cargo
    rustc
    nodejs
  ];
}
