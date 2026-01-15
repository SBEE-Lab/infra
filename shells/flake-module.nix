{
  perSystem =
    { pkgs, ... }:
    {
      devShells.default = pkgs.mkShellNoCC {
        buildInputs = with pkgs; [
          # deploy tools
          python3.pkgs.invoke
          python3.pkgs.deploykit
          python3.pkgs.bcrypt

          # nix tools
          nixVersions.latest
          nixos-rebuild
          nixos-anywhere

          # basic tools
          gitMinimal
          coreutils
          findutils
          rsync
          yq-go
          fd

          # secret tools
          openssh
          sops
          ssh-to-age
          age
          mkpasswd

          # network tools
          dnsmasq
          wireguard-tools
        ];
      };
    };
}
