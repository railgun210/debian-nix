# home-manager/home.nix
# Standalone Home Manager configuration for Debian: GNOME (Wayland) plus an
# alternate i3 (X11) session.
# Apply with: home-manager switch --flake .#railgun
{config, ...}: {
  imports = [
    # theming MUST be first: Stylix variables (colors, fonts) need to be
    # evaluated before utilities and desktops consume them.
    ./theming
    ./utilities
    ./desktops
  ];

  config = {
    # Required for standalone home-manager on non-NixOS systems.
    targets.genericLinux = {
      enable = true;
      # Expose Debian's NVIDIA driver to Nix-built GL/Vulkan apps (ghostty,
      # RetroArch, ...). Version MUST match Debian's nvidia-driver package.
      # After switching (and after any version bump), run the sudo command that
      # `home-manager switch` prints: sudo /nix/store/...-non-nixos-gpu/bin/non-nixos-gpu-setup
      gpu.nvidia = {
        enable = true;
        version = "550.163.01";
        sha256 = "sha256-74FJ9bNFlUYBRen7+C08ku5Gc1uFYGeqlIh7l1yrmi4=";
      };
    };

    # Flatpak's systemd env generator adds its export dirs to XDG_DATA_DIRS,
    # but the Home Manager session vars clobber it, so Flatpak apps never
    # reached the GNOME app grid/search. Add them here alongside genericLinux's.
    xdg.systemDirs.data = [
      "${config.home.homeDirectory}/.local/share/flatpak/exports/share"
      "/var/lib/flatpak/exports/share"
    ];

    home = {
      username = "railgun";
      homeDirectory = "/home/railgun";

      file."Wallpapers" = {
        source = ./wallpapers;
        recursive = true;
      };

      sessionVariables = {
        EDITOR = "emacsclient -a ''";
        VISUAL = "emacsclient -a ''";
        TERMINAL = "ghostty";
        BROWSER = "firefox-esr"; # Debian's apt Firefox ESR
      };

      # ~/.local/bin for user scripts, ~/.config/emacs/bin for Doom's `doom` CLI.
      sessionPath = [
        "$HOME/.local/bin"
        "$HOME/.config/emacs/bin"
      ];
    };

    programs.home-manager.enable = true;

    # Git identity. Written as a plain config file (not programs.git) because
    # git itself comes from apt on Debian; programs.git would install a second copy.
    # GitHub HTTPS URLs are rewritten to SSH so git authenticates with the
    # sops-managed key (utilities/ssh.nix) instead of prompting for a password.
    xdg.configFile."git/config".text = ''
      [user]
        name = railgun210
        email = aday56709@gmail.com
      [url "git@github.com:"]
        insteadOf = https://github.com/
    '';

    # Vanilla neovim (no plugins, for quick terminal edits)
    programs.neovim = {
      enable = true;
      withRuby = false;
      withPython3 = false;
    };

    systemd.user.startServices = "sd-switch";

    home.stateVersion = "25.11";
  };
}
