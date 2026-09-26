# home-manager/desktops/gnome/default.nix
# GNOME (Wayland, GDM) on Debian, set up to feel like MATE: GNOME Classic's top
# bar with Applications/Places menus, a bottom window list and a fixed set of
# workspaces.
#
# GNOME itself, its extensions and GDM come from apt (see docs/debian-setup.md).
# This module only configures them through dconf and adds the Nix-side pieces.
# Wallpaper, fonts, the dark colour scheme, icon theme and cursor come from
# Stylix (see theming/stylix.nix), so they are not repeated here.
{
  config,
  lib,
  pkgs,
  ...
}: let
  # Workspace keys shared with i3: Super+1..9 and Super+0 (= workspace 10)
  # switch, Super+Shift+<same key> moves the focused window there.
  workspaceKeys = lib.listToAttrs (map (n: {
    name = toString n;
    value =
      if n == 10
      then "0"
      else toString n;
  }) (lib.range 1 10));

  customBinding = name: "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/${name}";
  ghosttyBinding = customBinding "ghostty";
  ankiBinding = customBinding "anki";
  smileBinding = customBinding "smile";
in {
  # Wayland clipboard CLI (wl-copy / wl-paste); i3 uses xclip instead.
  home.packages = [pkgs.wl-clipboard];

  # GDM starts a systemd user session, which (unlike Debian's old LightDM ->
  # Xsession path) reads ~/.config/environment.d. Home Manager already writes
  # XDG_DATA_DIRS there, so Nix apps show up in the Activities grid. PATH is the
  # one thing it does not set, so desktop entries that call a bare command name
  # (Exec=kitty) still resolve.
  xdg.configFile."environment.d/20-nix-path.conf".text = ''
    PATH=${config.home.homeDirectory}/.nix-profile/bin:/nix/var/nix/profiles/default/bin:$PATH
  '';

  # Run Nix-built Electron apps (VS Code, Todoist) natively on Wayland
  # instead of through Xwayland. Written to the same environment.d file that
  # Home Manager generates for XDG_DATA_DIRS.
  systemd.user.sessionVariables.NIXOS_OZONE_WL = "1";

  # Monitor layout from Settings > Displays: the BenQ 4K at 60 Hz, scale 100%
  # (text-scaling-factor below makes text readable instead of fractional
  # scaling). GNOME replaces this file when display settings are changed, so
  # force lets the next switch put it back instead of failing on the clash.
  xdg.configFile."monitors.xml" = {
    force = true;
    text = ''
      <monitors version="2">
        <configuration>
          <layoutmode>logical</layoutmode>
          <logicalmonitor>
            <x>0</x>
            <y>0</y>
            <scale>1</scale>
            <primary>yes</primary>
            <monitor>
              <monitorspec>
                <connector>DP-3</connector>
                <vendor>BNQ</vendor>
                <product>BenQ EW2880U</product>
                <serial>ETA9P04314SL0</serial>
              </monitorspec>
              <mode>
                <width>3840</width>
                <height>2160</height>
                <rate>59.997</rate>
              </mode>
            </monitor>
          </logicalmonitor>
        </configuration>
      </monitors>
    '';
  };

  dconf.settings = {
    "org/gnome/settings-daemon/plugins/media-keys" = {
      # Super+T opens Ghostty (same as i3).
      custom-keybindings = [
        "/${ghosttyBinding}/"
        "/${ankiBinding}/"
        "/${smileBinding}/"
      ];
      home = ["<Shift><Super>e"]; # file manager
      www = ["<Super>b"]; # web browser
    };
    ${ghosttyBinding} = {
      name = "Ghostty";
      command = "${config.programs.ghostty.package}/bin/ghostty";
      binding = "<Super>t";
    };
    # Anki from /usr/local/bin (Anki's own installer, not apt or nix).
    ${ankiBinding} = {
      name = "Anki";
      command = "anki";
      binding = "<Shift><Super>a";
    };
    # Smile emoji picker (Flatpak).
    ${smileBinding} = {
      name = "Smile";
      command = "flatpak run it.mijorus.smile";
      binding = "<Shift><Super>period";
    };

    "org/gnome/desktop/wm/keybindings" = lib.mkMerge [
      (lib.mapAttrs' (n: key: lib.nameValuePair "switch-to-workspace-${n}" ["<Super>${key}"]) workspaceKeys)
      (lib.mapAttrs' (n: key: lib.nameValuePair "move-to-workspace-${n}" ["<Super><Shift>${key}"]) workspaceKeys)
      {
        close = ["<Super>q"];
        panel-run-dialog = ["<Super>d"];
      }
    ];

    # GNOME binds Super+1..9 to "launch the Nth dock favourite" by default,
    # which would swallow the workspace keys above.
    "org/gnome/shell/keybindings" = lib.mkMerge [
      (lib.genAttrs (map (n: "switch-to-application-${toString n}") (lib.range 1 9)) (_: []))
      {screenshot-window = ["<Shift><Super>s"];}
    ];

    "org/gnome/shell" = {
      disable-user-extensions = false;
      # UUIDs come from the Debian gnome-shell-extension* packages. GNOME Classic
      # enables its own set in the classic session; listing them here makes the
      # regular GNOME session look the same.
      enabled-extensions = [
        "apps-menu@gnome-shell-extensions.gcampax.github.com"
        "places-menu@gnome-shell-extensions.gcampax.github.com"
        "window-list@gnome-shell-extensions.gcampax.github.com"
        "launch-new-instance@gnome-shell-extensions.gcampax.github.com"
        "drive-menu@gnome-shell-extensions.gcampax.github.com"
        "user-theme@gnome-shell-extensions.gcampax.github.com"
        "ubuntu-appindicators@ubuntu.com" # tray icons (Debian's AppIndicator package)
        "ding@rastersoft.com" # desktop icons
      ];
      # Extensions turned off by hand. Listed so Classic mode does not re-enable
      # them; workspace-indicator is left out of enabled-extensions above for the
      # same reason.
      disabled-extensions = [
        "system-monitor@gnome-shell-extensions.gcampax.github.com"
        "workspace-indicator@gnome-shell-extensions.gcampax.github.com"
        "windowsNavigator@gnome-shell-extensions.gcampax.github.com"
      ];
    };

    # Bottom window list like MATE's: windows grouped only when space runs out,
    # limited to the current workspace.
    "org/gnome/shell/extensions/window-list" = {
      grouping-mode = "auto";
      display-all-workspaces = false;
    };

    "org/gnome/desktop/interface" = {
      clock-show-date = true;
      enable-hot-corners = false; # MATE has no hot corner
      text-scaling-factor = 1.7;

      # Smooth text with subpixel rendering. Keep in sync with
      # theming/font-settings.nix, which sets the same values for fontconfig.
      font-antialiasing = "rgba";
      font-hinting = "slight";
      font-rgba-order = "rgb";
    };

    # Minimize/maximize/close on the right, no app-menu button.
    "org/gnome/desktop/wm/preferences" = {
      button-layout = ":minimize,maximize,close";
      num-workspaces = 10; # Super+1..0, same as i3
    };

    # Alt+Tab only lists windows on the current workspace.
    "org/gnome/shell/app-switcher".current-workspace-only = true;

    # Nautilus opens new windows at this size (its default is 890x550, too
    # small on the 4K screen). Nautilus overwrites it with the last closed
    # window's size; Home Manager puts it back on each switch.
    "org/gnome/nautilus/window-state" = {
      initial-size = lib.hm.gvariant.mkTuple [1780 1100];
      maximized = false;
    };

    # Night Light follows a manual schedule instead of sunrise/sunset.
    "org/gnome/settings-daemon/plugins/color".night-light-schedule-automatic = false;

    "org/gnome/mutter" = {
      dynamic-workspaces = false; # fixed workspaces, like MATE's switcher
      edge-tiling = true;
    };
  };
}
