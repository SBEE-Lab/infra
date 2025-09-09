{ pkgs, ... }:
{
  # Reboot after 5 min
  systemd.services.kexec-safety-reboot = {
    description = "Safety reboot if no SSH connection within 45 minutes";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.systemd}/bin/systemctl reboot";
    };
  };

  systemd.timers.kexec-safety-reboot = {
    description = "Timer for safety reboot after kexec";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "45min";
      Unit = "kexec-safety-reboot.service";
    };
  };

  # Cancel timer when SSH connected
  systemd.services.kexec-safety-cancel = {
    description = "Cancel safety reboot timer on successful SSH connection";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeScript "cancel-safety-timer" ''
        #!${pkgs.bash}/bin/bash
        echo "SSH connection detected, canceling safety reboot timer"
        ${pkgs.systemd}/bin/systemctl stop kexec-safety-reboot.timer
        ${pkgs.systemd}/bin/systemctl disable kexec-safety-reboot.timer
        echo "Safety reboot timer canceled successfully"
      '';
    };
  };

  services.openssh.extraConfig = ''
    ForceCommand if [ "$SSH_ORIGINAL_COMMAND" = "" ]; then systemctl start kexec-safety-cancel.service 2>/dev/null || true; exec bash -l; else exec $SSH_ORIGINAL_COMMAND; fi
  '';
}
