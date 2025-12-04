{pkgs, ...}: {
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

    # managed by toolz (release-25.05)
    # keep-sorted start
    alphafold3
    edirect
    flash
    foldseek
    infernal
    interproscan
    jellyfish-full
    kmc
    locarna
    ncbi-dataformat
    ncbi-datasets
    nupack
    openzl
    vsearch
    # keep-sorted end
  ];
}
