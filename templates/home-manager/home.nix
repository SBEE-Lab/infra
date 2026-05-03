# docs: find home manager options here:
# https://nix-community.github.io/home-manager/options.html
{
  pkgs,
  username,
  ...
}:
{
  config = {
    home.packages = with pkgs; [
      uutils-coreutils-noprefix
      htop
      btop
      tmux
      upterm
      git
      rsync
      wget
      curl
      ripgrep
      fd
      jq
      dust
      ncdu
      tree
    ];

    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    nix.settings.extra-experimental-features = [
      "nix-command"
      "flakes"
    ];

    programs.zsh = {
      enable = true;
      # `upterm-tmux <github-username>` — share a tmux session via the
      # mulatta uptermd relay. Pair-programming session name matches the
      # convention shown at https://upterm.mulatta.io.
      initContent = ''
        upterm-tmux() {
          if [ -z "$1" ]; then
            echo "Usage: upterm-tmux <github-username>" >&2
            return 1
          fi
          upterm host \
            --github-user "$1" \
            --server ssh://upterm.mulatta.io:2323 \
            --force-command 'tmux attach -t pair-programming' \
            -- tmux new -A -s pair-programming
        }
      '';
    };

    home.stateVersion = "25.11";
    home.username = username;
    home.homeDirectory = "/home/${username}";
    xdg.cacheHome = "/scratch/${username}/.cache";
    xdg.stateHome = "/scratch/${username}/.local/share";
  };
}
