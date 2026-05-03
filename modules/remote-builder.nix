{ config, lib, ... }:
let
  inherit (config.networking) hostName;

  # Private half lives outside infra in the dots clan var
  # psi-builder/ssh-key. It is used by the root nix-daemon on rhesus, not by
  # interactive admin SSH, so keep it separate from the Secretive admin key.
  builderPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGf6fKb1r0vzdHyLRyoJ5TgFG8PkL3UQw8nISGJWUdMF seungwon@rhesus";

  # eta is only a WireGuard jump from rhesus to psi's SSH port. The source and
  # destination limits keep this key from becoming a general-purpose bastion key.
  etaJumpKey = ''from="10.100.0.200",restrict,port-forwarding,permitopen="10.100.0.2:10022" ${builderPublicKey}'';

  # psi runs the actual Nix builder, so command execution is intentionally
  # allowed, but only when the connection arrives from eta over wg-admin.
  psiBuilderKey = ''from="10.100.0.1" ${builderPublicKey}'';
in
{
  users.users.root.openssh.authorizedKeys.keys =
    lib.optionals (hostName == "eta") [ etaJumpKey ]
    ++ lib.optionals (hostName == "psi") [ psiBuilderKey ];
}
