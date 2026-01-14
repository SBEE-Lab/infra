{ pkgs, ... }:
{
  programs.tmux = {
    enable = true;
    shortcut = "a";
    keyMode = "vi";
    baseIndex = 1;
    escapeTime = 0;
    historyLimit = 100000;
    terminal = "screen-256color";
    newSession = true;
    secureSocket = false;

    plugins = with pkgs.tmuxPlugins; [
      sensible
      resurrect
    ];

    extraConfig = ''
      set -g mouse on

      set -g history-limit 100000
      set -sg escape-time 0
      set -g display-time 4000

      set -g status-interval 30
      set -g status-right "#{host} | %H:%M"

      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"

      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R

      bind s choose-tree -Zs
    '';
  };

  services.logind.killUserProcesses = false;
}
