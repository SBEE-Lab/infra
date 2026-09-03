{
  self,
  inputs,
  ...
}:
let
  inherit (inputs)
    nixpkgs
    authentik-nix
    disko
    dure
    fast-nix-gc
    sops-nix
    srvos
    ;

  system = "x86_64-linux";

  lib = nixpkgs.lib.extend (
    _: _: {
      sbee = self.lib.sbee;
    }
  );

  stalwartR2Overlay = _final: prev: {
    # rust-s3 0.35 signs empty body headers on ranged GET and DELETE.
    # Cloudflare R2 rejects those signatures, breaking JMAP attachment
    # downloads and blob garbage collection. Keep this until rust-s3 merges
    # PRs #459/#467 and Stalwart bumps the crate.
    stalwart = prev.stalwart_0_15.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [
        ./packages/stalwart/return-empty-s3-blob-for-empty-range.patch
      ];

      cargoDeps =
        let
          rust-s3-r2-range-get-signing-fix = prev.fetchpatch {
            url = "https://github.com/durch/rust-s3/commit/4c7ed2b44d6fbf1ebdd401dd3a81c14d288cffb2.patch";
            relative = "s3";
            hash = "sha256-f4OBtd/XcERHSckluRh2ESTumygIMnEv7GMqPXT18QQ=";
          };
        in
        prev.runCommand "${old.pname}-${old.version}-vendor-rust-s3-r2-signing-fixes" { } ''
          cp -R ${old.cargoDeps} "$out"
          chmod -R u+w "$out/source-registry-0/rust-s3-0.35.1"
          cd "$out/source-registry-0/rust-s3-0.35.1"
          patch -p1 < ${rust-s3-r2-range-get-signing-fix}
          patch -p1 < ${./packages/stalwart/rust-s3-skip-delete-object-body-headers.patch}
          grep -F 'Command::GetObjectRange { .. } => {}' src/request/request_trait.rs
          grep -F 'Command::DeleteObject => {}' src/request/request_trait.rs
        '';
    });
  };

  pkgs = import nixpkgs {
    inherit system;
    overlays = [ stalwartR2Overlay ];
  };

  # CUDA-enabled pkgs for GPU hosts (psi)
  pkgsCuda = import nixpkgs {
    inherit system;
    config.cudaSupport = true;
  };

  nixosSystem =
    {
      modules,
      useCuda ? false,
    }:
    lib.nixosSystem {
      inherit system;
      specialArgs = { inherit self inputs lib; };
      modules = modules ++ [ { nixpkgs.pkgs = if useCuda then pkgsCuda else pkgs; } ];
    };

  commonModules = [
    ./modules/auto-upgrade.nix
    ./modules/cleanup-usr.nix
    ./modules/hosts.nix
    ./modules/network.nix
    ./modules/nix-daemon.nix
    ./modules/nix-index.nix
    ./modules/packages.nix
    ./modules/register-flake.nix
    ./modules/remote-builder.nix
    ./modules/sshd
    ./modules/users/admins.nix
    ./modules/users/extra-user-options.nix
    ./modules/zram.nix

    disko.nixosModules.disko
    fast-nix-gc.nixosModules.default
    srvos.nixosModules.server
    srvos.nixosModules.mixins-terminfo
    srvos.nixosModules.mixins-nix-experimental

    ./modules/tinc.nix
    dure.nixosModules.naru
    dure.nixosModules.ca

    ./modules/users
    ./modules/bootloader.nix
    sops-nix.nixosModules.sops
    ./modules/sops
    ({ lib, ... }: {
      time.timeZone = lib.mkForce "Asia/Seoul";
    })
  ];

  computeModules = commonModules ++ [
    ./modules/project-space.nix
    ./modules/workspace-space.nix
    ./modules/blobs-space.nix
    ./modules/nix-ld.nix
  ];
in
{
  flake.nixosConfigurations = {
    psi = nixosSystem {
      modules = computeModules ++ [ ./hosts/psi.nix ];
      useCuda = true;
    };
    rho = nixosSystem { modules = commonModules ++ [ ./hosts/rho.nix ]; };
    tau = nixosSystem { modules = commonModules ++ [ ./hosts/tau.nix ]; };
    eta = nixosSystem {
      modules = commonModules ++ [
        authentik-nix.nixosModules.default
        ./hosts/eta.nix
      ];
    };
  };
}
