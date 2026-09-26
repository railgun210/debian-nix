# home-manager/utilities/ghostty.nix
# Ghostty terminal configuration
{config, ...}: let
  c = config.lib.stylix.colors;
in {
  programs.ghostty = {
    enable = true;
    enableZshIntegration = true;

    settings = {
      font-family = config.stylix.fonts.monospace.name;
      font-size = 14;

      background-opacity = 0.9; # 0.0 = fully transparent, 1.0 = fully opaque;
      background-blur = false;

      window-padding-x = 10;
      window-padding-y = 10;
      # GNOME/mutter has no server-side decorations, so let Ghostty draw its own
      # libadwaita titlebar (window can be moved, resized and snapped). i3
      # launches it with --window-decoration=none instead.
      window-decoration = "auto";
      gtk-titlebar = true;
      window-width = 240; # initial size in cells; also stops the tiny corner window
      window-height = 70;
      window-save-state = "never";
      confirm-close-surface = false;
      gtk-single-instance = false; # one process per window, so closing one window never affects another

      shell-integration = "zsh";

      clipboard-read = "allow";
      clipboard-write = "allow";

      mouse-hide-while-typing = true;

      scrollback-limit = 100000;

      # Standard base16 -> ANSI mapping (same as base16-shell / Stylix terminals).
      # 0-15 are the ANSI colors, 16-21 hold the remaining base16 slots.
      palette = [
        "0=#${c.base00}"
        "1=#${c.base08}"
        "2=#${c.base0B}"
        "3=#${c.base0A}"
        "4=#${c.base0D}"
        "5=#${c.base0E}"
        "6=#${c.base0C}"
        "7=#${c.base05}"
        "8=#${c.base03}"
        "9=#${c.base08}"
        "10=#${c.base0B}"
        "11=#${c.base0A}"
        "12=#${c.base0D}"
        "13=#${c.base0E}"
        "14=#${c.base0C}"
        "15=#${c.base07}"
        "16=#${c.base09}"
        "17=#${c.base0F}"
        "18=#${c.base01}"
        "19=#${c.base02}"
        "20=#${c.base04}"
        "21=#${c.base06}"
      ];
    };
  };
}
