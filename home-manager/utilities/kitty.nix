# home-manager/utilities/kitty.nix
# Kitty terminal — kept as a backup/secondary terminal. Primary terminal is Ghostty.
# To switch: change TERMINAL in home.nix and the Super+T bindings in
# desktops/gnome/default.nix and desktops/i3/i3.nix. Colours come from Stylix.
{
  config,
  lib,
  ...
}: {
  programs.kitty = {
    enable = true;
    font = {
      name = config.stylix.fonts.monospace.name;
      size = lib.mkForce 14; # Stylix's terminal size is 12
    };

    settings = {
      allow_remote_control = "socket-only";
      close_on_child_death = true;
      cursor_shape = "beam";
      enable_audio_bell = false;
      listen_on = "unix:${config.home.homeDirectory}/.local/share/kitty/kitty.sock";
      mouse_hide_wait = 0;
      scrollback_lines = 100000;
      strip_trailing_spaces = "always";
      touch_scroll_multiplier = 20;

      remember_window_size = false;
      initial_window_width = 1000;
      initial_window_height = 600;
    };

    keybindings."kitty_mod+0" = "change_font_size all 0";
  };

  # Directory for the listen_on socket above.
  home.file.".local/share/kitty/.keep".text = "";
}
