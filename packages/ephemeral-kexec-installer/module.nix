{
  config,
  lib,
  pkgs,
  ...
}:
let
  restoreScript = pkgs.writeShellScript "restore-ephemeral-kexec-network" ''
    set -eu

    test -f /etc/ephemeral-kexec/marker
    test -f /etc/ephemeral-kexec/private-key
    test -f /etc/systemd/network/10-wg-install.netdev
    test -f /etc/systemd/network/10-wg-install.network

    chown systemd-network:systemd-network /etc/ephemeral-kexec/private-key
    chmod 0400 /etc/ephemeral-kexec/private-key
  '';
in
{
  boot.kernelModules = [ "wireguard" ];

  # The normal kexec runner modifies the extracted initrd. This variant builds
  # the secret-bearing initrd only below /run and removes it after kexec --load.
  system.build.kexecRun = lib.mkForce (
    pkgs.runCommand "ephemeral-kexec-run" { } ''
      install -D -m 0755 ${./kexec-run.sh} $out
      substituteInPlace $out \
        --replace-fail '@init@' '${config.system.build.toplevel}/init' \
        --replace-fail '@kernelParams@' '${lib.escapeShellArgs config.boot.kernelParams}'
      ${pkgs.shellcheck}/bin/shellcheck $out
    ''
  );

  boot.initrd.systemd.services.restore-state-from-initrd.script = lib.mkAfter ''
    if [[ -f ephemeral-kexec/marker ]]; then
      install -d -m 0700 /sysroot/etc/ephemeral-kexec
      install -d -m 0755 /sysroot/etc/systemd/network
      install -m 0400 ephemeral-kexec/private-key /sysroot/etc/ephemeral-kexec/private-key
      install -m 0644 ephemeral-kexec/wg-install.network \
        /sysroot/etc/systemd/network/10-wg-install.network
      ${pkgs.gnused}/bin/sed \
        's#/run/systemd/network/wg-install.key#/etc/ephemeral-kexec/private-key#' \
        ephemeral-kexec/wg-install.netdev \
        > /sysroot/etc/systemd/network/10-wg-install.netdev
      chmod 0644 /sysroot/etc/systemd/network/10-wg-install.netdev
      touch /sysroot/etc/ephemeral-kexec/marker
    fi
  '';

  systemd.services.ephemeral-kexec-network = {
    description = "Validate ephemeral kexec WireGuard credentials";
    requiredBy = [ "systemd-networkd.service" ];
    before = [
      "network-pre.target"
      "systemd-networkd.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = restoreScript;
    };
  };

  systemd.services.systemd-networkd = {
    after = [ "ephemeral-kexec-network.service" ];
    requires = [ "ephemeral-kexec-network.service" ];
  };
}
