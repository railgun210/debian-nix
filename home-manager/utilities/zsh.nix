# home-manager/utilities/zsh.nix
# Zsh shell configuration
# Note: If you have a running zsh session you're gonna have to do source ~/.zshrc for the changes to load.
{
  config,
  pkgs,
  ...
}: {
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    enableCompletion = true;

    # History settings
    history = {
      size = 10000;
      save = 10000;
      path = "${config.home.homeDirectory}/.zsh_history";
      ignoreDups = true;
      share = true;
    };

    # Oh-My-Zsh
    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "docker"
        "sudo"
        "fzf"
        # direnv's hook comes from programs.direnv (development-tools.nix)
      ];
    };

    # Powerlevel10k theme
    plugins = [
      {
        name = "powerlevel10k";
        src = pkgs.zsh-powerlevel10k;
        file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
      }
    ];

    # Shell aliases
    shellAliases = {
      # General
      ll = "eza -la --icons=auto";
      ls = "eza --icons=auto";
      cat = "bat";
      grep = "rg";
      find = "fd";

      # Git
      gs = "git status";
      ga = "git add";
      gc = "git commit";
      gp = "git push";
      gl = "git pull";
      gd = "git diff";
      gco = "git checkout";

      # Backup — make the Dallas 5TB drive writable and claim ownership of the
      # borg repo. udisks2 mounts removable drives under /media/$USER on Debian.
      mount-dallas-zero = "sudo sh -c 'mount -o remount,rw /media/${config.home.username}/dallas_0 && chown -R ${config.home.username}: /media/${config.home.username}/dallas_0/railgun-desktop-backup'";

      cleanup = "sudo nix-collect-garbage -d && nix-collect-garbage -d";
    };

    # Init content
    initContent = ''
      # FZF configuration
      export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
      export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'

      # Powerlevel10k config (must come after theme is sourced above)
      [[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

      # ── Home Manager commands: nsr, nrt, nfu, update, dotfiles ──
      # Nix can't know where this repo is checked out (flakes are evaluated from
      # a store copy), so find it at run time: $DOTFILES_DIR, else the repo
      # you're in, else the last one that worked, else ~/GitRepos/debian-nix.
      # Whatever works is remembered, so after moving the repo, run a command
      # once from inside it. scripts/bootstrap.sh seeds the same file.
      _dotfiles_state="''${XDG_STATE_HOME:-$HOME/.local/state}/debian-nix/path"

      function dotfiles-dir {
        local d saved=""
        [[ -r $_dotfiles_state ]] && saved="$(<$_dotfiles_state)"
        for d in "$DOTFILES_DIR" "$(git rev-parse --show-toplevel 2>/dev/null)" "$saved" "$HOME/GitRepos/debian-nix"; do
          [[ -n $d && -f $d/flake.nix && -f $d/home-manager/home.nix ]] || continue
          d=''${d:A}
          if [[ $d != "$saved" ]]; then
            mkdir -p "''${_dotfiles_state:h}" && print -r -- "$d" > "$_dotfiles_state"
          fi
          print -r -- "$d"
          return 0
        done
        print -u2 "debian-nix repo not found. cd into your clone and run this again, or set DOTFILES_DIR=/path/to/debian-nix."
        return 1
      }

      function nsr { local d; d="$(dotfiles-dir)" || return; home-manager switch --flake "$d#railgun" "$@"; }
      function nrt { local d; d="$(dotfiles-dir)" || return; home-manager build --flake "$d#railgun" "$@"; }
      function nfu { local d; d="$(dotfiles-dir)" || return; nix flake update --flake "$d" "$@"; }
      # Update inputs and re-apply home-manager
      function update { nfu && nsr; }
      # cd into the repo
      function dotfiles { local d; d="$(dotfiles-dir)" && cd -- "$d"; }
    '';
  };

  # Extra completion definitions (the plugins above are loaded by programs.zsh)
  home.packages = [pkgs.zsh-completions];
}
