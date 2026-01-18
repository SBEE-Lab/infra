{ pkgs, ... }:
{
  programs.singularity = {
    enable = true;
    package = pkgs.apptainer;
  };

  environment.systemPackages = with pkgs; [
    # compilers
    stdenv.cc.cc.lib
    gcc

    zlib
    libGL

    # javascript
    nodejs

    # rust
    pkg-config
    cargo
    rustc

    # python
    uv
    pixi

    viennarna
    blast
    nextflow
  ];
}
