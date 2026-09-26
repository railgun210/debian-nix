# home-manager/desktops/i3/picom.nix
# picom itself comes from apt (GLX straight on Debian's NVIDIA driver) and is
# started by i3, not by a systemd user service, so it never runs under GNOME.
# Ported from ~/GitRepos/dotfiles/picom.
{...}: {
  xdg.configFile."picom/picom.conf".text = ''
    # ===== BACKEND =====
    backend = "glx";

    # NVIDIA-specific GLX options: prevent tearing and flicker
    glx-copy-from-front = false;
    use-damage = false;
    xrender-sync-fence = true;

    # ===== SHADOWS =====
    shadow = true;
    shadow-radius = 14;
    shadow-offset-x = -12;
    shadow-offset-y = -12;
    shadow-opacity = 0.4;
    shadow-exclude = [
      "name = 'Notification'",
      "class_g = 'Dunst'",
      "class_g = 'dmenu'",
      "class_g = 'i3bar'",
      "class_g = 'slop'",
      "_GTK_FRAME_EXTENTS@:c"
    ];

    # ===== FADING =====
    fading = true;
    fade-in-step = 0.06;
    fade-out-step = 0.06;
    fade-delta = 8;

    # ===== BLUR =====
    blur-method = "dual_kawase";
    blur-strength = 6;
    blur-background = true;
    blur-background-frame = true;
    blur-background-fixed = false;
    blur-background-exclude = [
      "class_g = 'slop'",
      "class_g = 'Dunst'",
      "window_type = 'dock'",
      "window_type = 'desktop'"
    ];

    # ===== ROUNDED CORNERS =====
    corner-radius = 18;
    rounded-corners-exclude = [
      "window_type = 'dock'",
      "window_type = 'desktop'",
      "class_g = 'i3bar'",
      "class_g = 'dmenu'"
    ];

    # ===== TRANSPARENCY / OPACITY =====
    inactive-opacity = 0.92;
    active-opacity = 1.0;
    frame-opacity = 1.0;
    inactive-opacity-override = false;

    opacity-rule = [
      "90:class_g = 'com.mitchellh.ghostty'",
      "90:class_g = 'kitty'",
      "95:class_g = 'Code'",
      "100:class_g = 'Dunst'",
      "100:class_g = 'dmenu'",
      "100:window_type = 'dialog'",
      "100:window_type = 'popup_menu'"
    ];

    # ===== GENERAL =====
    vsync = true;
    mark-wmwin-focused = true;
    mark-ovredir-focused = true;
    detect-rounded-corners = true;
    detect-client-opacity = true;
    detect-transient = true;
    detect-client-leader = true;
    log-level = "warn";

    wintypes:
    {
      tooltip       = { fade = true; shadow = false; opacity = 0.9; focus = true; };
      dock          = { shadow = false; clip-shadow-above = true; };
      dnd           = { shadow = false; };
      popup_menu    = { opacity = 1.0; };
      dropdown_menu = { opacity = 1.0; };
    };
  '';
}
