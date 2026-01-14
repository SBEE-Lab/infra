{
  config,
  lib,
  pkgs,
  ...
}:
let
  hasNvidia = builtins.elem "nvidia" config.services.xserver.videoDrivers;
in
{
  programs.nix-ld = {
    enable = true;
    libraries =
      with pkgs;
      [
        stdenv.cc.cc.lib
        openssl
        zlib
        curl
        libGL
      ]
      ++ lib.optionals hasNvidia [
        config.boot.kernelPackages.nvidiaPackages.production
        cudaPackages.cuda_cudart
        cudaPackages.cudnn
        cudaPackages.cudatoolkit
      ];
  };
}
