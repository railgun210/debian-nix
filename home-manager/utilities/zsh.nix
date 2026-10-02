# home-manager/utilities/zsh.nix
{
  config,
  pkgs,
  ...
}:
{
  # Paths for manually-installed binaries that live outside the Nix store.
  home.sessionPath = [
    "/usr/local/nvim-linux-x86_64/bin"
  ];

  home.packages = [ pkgs.zsh-completions ];

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    enableCompletion = true;

    history = {
      size = 10000;
      save = 10000;
      path = "${config.home.homeDirectory}/.zsh_history";
      ignoreDups = true;
      share = true;
    };

    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "docker"
        "sudo"
        "fzf"
        # direnv hook comes from programs.direnv (development-tools.nix)
      ];
    };

    plugins = [
      {
        name = "powerlevel10k";
        src = pkgs.zsh-powerlevel10k;
        file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
      }
    ];

    sessionVariables = {
      FZF_DEFAULT_COMMAND = "fd --type f --hidden --follow --exclude .git";
      FZF_DEFAULT_OPTS = "--height 40% --layout=reverse --border";
    };

    shellAliases = {
      # Modern CLI replacements
      ll = "eza -la --icons=auto";
      ls = "eza --icons=auto";
      cat = "bat";
      grep = "rg";
      find = "fd";

      # Git shortcuts
      gs = "git status";
      ga = "git add";
      gc = "git commit";
      gp = "git push";
      gl = "git pull";
      gd = "git diff";
      gco = "git checkout";

      # Common commands
      neovim = "nvim";

      # Nix
      cleanup = "nix-collect-garbage -d";

    };

    initContent = ''
      # Powerlevel10k config (must come after the theme is sourced above)
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
      function update { nfu && nsr; }
      function dotfiles { local d; d="$(dotfiles-dir)" && cd -- "$d"; }
    '';
  };
}
