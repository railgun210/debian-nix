# home-manager/desktops/i3/i3.nix
{
  config,
  lib,
  pkgs,
  ...
}:
let
  mod  = "Mod4";
  term = "ghostty --window-decoration=none";

  # -------------------------------------------------------------------
  # Workspace names
  # -------------------------------------------------------------------
  # Format: "N:icon label".
  # Top bar uses strip_workspace_name (extraConfig) to show only "N".
  # Bottom bar uses workspaceNumbers = false to show only "icon label".
  # Edit the icons and labels here; the number prefix must stay for
  # strip_workspace_name / strip_workspace_numbers to split on.
  wsNames = {
    "1"  = "1: Browser";
    "2"  = "2:󰆍 Terminal";
    "3"  = "3: Code";
    "4"  = "4:󰎁 Media";
    "5"  = "5:󰎈 Music";
    "6"  = "6:󰊗 Games";
    "7"  = "7:󰇮 Mail";
    "8"  = "8:󱈹 Workspace";
    "9"  = "9:󰏆 Office";
    "10" = "10:󰭹 Chat";
  };
  ws = n: wsNames.${toString n};

  # -------------------------------------------------------------------
  # Keybinding helpers
  # -------------------------------------------------------------------
  # vim-style direction keys, shifted one to the right like the old config
  left  = "j";
  down  = "k";
  up    = "l";
  right = "semicolon";

  # Super+1..9 and Super+0 (= workspace 10), same as the GNOME setup
  key = n: if n == 10 then "0" else toString n;

  workspaceBindings = lib.listToAttrs (
    lib.concatMap (n: [
      (lib.nameValuePair "${mod}+${key n}"       "workspace ${ws n}")
      (lib.nameValuePair "${mod}+Shift+${key n}" "move container to workspace ${ws n}")
    ]) (lib.range 1 10)
  );

  # -------------------------------------------------------------------
  # Misc helpers
  # -------------------------------------------------------------------
  # i3lock only reads PNG, so convert the Stylix wallpaper at build time.
  lockImage = pkgs.runCommand "i3lock-wallpaper.png"
    { nativeBuildInputs = [ pkgs.imagemagick ]; }
    ''magick ${config.stylix.image} -resize 3840x2160^ -gravity center -extent 3840x2160 png:$out'';

  polkitAgent = "/usr/libexec/polkit-mate-authentication-agent-1";

  c = config.lib.stylix.colors;

  # Bar font — Nerd Font required for i3status-rust block icons.
  barFont = {
    names = [
      config.stylix.fonts.monospace.name
      "Symbols Nerd Font Mono"
    ];
    style = "Regular";
    size  = 15.0;
  };

  # Shared workspace button colours used by both bars.
  barColors = {
    background = "#${c.base00}";
    statusline = "#${c.base05}";
    separator  = "#${c.base00}";
    focusedWorkspace = {
      border     = "#${c.base00}";
      background = "#${c.base02}";
      text       = "#${c.base05}";
    };
    inactiveWorkspace = {
      border     = "#${c.base00}";
      background = "#${c.base00}";
      text       = "#${c.base05}";
    };
    urgentWorkspace = {
      border     = "#${c.base00}";
      background = "#${c.base0E}";
      text       = "#${c.base05}";
    };
  };

in
{
  xsession.windowManager.i3 = {
    enable = true;
    config = {
      modifier         = mod;
      terminal         = term;
      defaultWorkspace = "workspace ${ws 1}";

      # -------------------------------------------------------------------
      # Gaps
      # -------------------------------------------------------------------
      gaps = {
        inner        = 10;
        outer        = 10;
        smartBorders = "on";
      };

      # -------------------------------------------------------------------
      # Window rules
      # -------------------------------------------------------------------
      window = {
        border          = 0;
        titlebar        = false;
        hideEdgeBorders = "both";
        commands = [
          {
            criteria.instance = "floating_term";
            command = "floating enable, resize set 800 600";
          }
          # Smile emoji picker: floating window centered on screen.
          {
            criteria.class = "^smile$";
            command = "floating enable, move position center";
          }
        ];
      };

      # -------------------------------------------------------------------
      # Workspace assigns
      # -------------------------------------------------------------------
      assigns = {
        ${ws 4} = [ { class = "^vlc$"; } ];
        ${ws 5} = [ { class = "^Strawberry$"; } ];
        ${ws 6} = [ { class = "^steam$"; } ];
        ${ws 7} = [
          { class = "^org.mozilla.Thunderbird$"; }
          { class = "^thunderbird$"; }
        ];
      };

      # -------------------------------------------------------------------
      # Keybindings
      # -------------------------------------------------------------------
      keybindings = workspaceBindings // {

        # Focus / move
        "${mod}+${left}"        = "focus left";
        "${mod}+${down}"        = "focus down";
        "${mod}+${up}"          = "focus up";
        "${mod}+${right}"       = "focus right";
        "${mod}+Shift+${left}"  = "move left";
        "${mod}+Shift+${down}"  = "move down";
        "${mod}+Shift+${up}"    = "move up";
        "${mod}+Shift+${right}" = "move right";

        "${mod}+f"           = "fullscreen toggle";
        "${mod}+a"           = "focus parent";
        "${mod}+space"       = "floating toggle";
        "${mod}+Shift+space" = "focus mode_toggle";

        # Workspace cycling
        "${mod}+bracketright"       = "workspace next";
        "${mod}+bracketleft"        = "workspace prev";
        "${mod}+period"             = "workspace next";
        "${mod}+comma"              = "workspace prev";
        "${mod}+Tab"                = "workspace next";
        "${mod}+Shift+Tab"          = "workspace prev";
        "${mod}+Shift+bracketright" = "move container to workspace next; workspace next";
        "${mod}+Shift+bracketleft"  = "move container to workspace prev; workspace prev";

        # Launchers
        "${mod}+d"            = "exec --no-startup-id desktop-launcher";
        "${mod}+t"            = "exec ${term}";
        "${mod}+Return"       = "exec ${term}";
        "${mod}+b"            = "exec firefox-esr";
        "${mod}+Shift+e"      = "exec nautilus";
        "Ctrl+Mod1+z"         = "exec emacsclient -c -a ''";
        "${mod}+Shift+a"      = "exec anki";
        "${mod}+Shift+period" = "exec flatpak run it.mijorus.smile";
        "${mod}+s"            = "exec --no-startup-id ${pkgs.maim}/bin/maim -s -u | ${pkgs.xclip}/bin/xclip -selection clipboard -t image/png -i";

        # i3 controls
        "${mod}+q"       = "kill";
        "${mod}+Shift+c" = "reload";
        "${mod}+Shift+r" = "restart";
        "${mod}+r"       = "mode resize";

        # Power menu and lock (xss-lock runs i3lock on lock-session)
        "${mod}+Shift+x" = "exec --no-startup-id powermenu-dmenu";
        "${mod}+x"       = "exec --no-startup-id loginctl lock-session";

        # Volume / brightness
        "Ctrl+Mod1+1"           = "exec --no-startup-id pamixer -d 10";
        "Ctrl+Mod1+2"           = "exec --no-startup-id pamixer -i 10";
        "Ctrl+Mod1+3"           = "exec --no-startup-id pamixer -t";
        "${mod}+Shift+v"        = "exec --no-startup-id pavucontrol";
        "XF86AudioLowerVolume"  = "exec --no-startup-id pamixer -d 5";
        "XF86AudioRaiseVolume"  = "exec --no-startup-id pamixer -i 5";
        "XF86AudioMute"         = "exec --no-startup-id pamixer -t";
        "XF86MonBrightnessDown" = "exec --no-startup-id brightnessctl set 5%-";
        "XF86MonBrightnessUp"   = "exec --no-startup-id brightnessctl set +5%";

      };

      # -------------------------------------------------------------------
      # Resize mode
      # -------------------------------------------------------------------
      modes.resize = {
        "${left}"  = "resize shrink width 10 px or 10 ppt";
        "${down}"  = "resize grow height 10 px or 10 ppt";
        "${up}"    = "resize shrink height 10 px or 10 ppt";
        "${right}" = "resize grow width 10 px or 10 ppt";
        "Escape"   = "mode default";
        "Return"   = "mode default";
      };

      # -------------------------------------------------------------------
      # Startup
      # -------------------------------------------------------------------
      startup = [
        { command = "xrdb -merge ~/.Xresources";                                                         notification = false;                  }
        { command = "setxkbmap -layout us,latam -option grp:alt_shift_toggle"; always = true;            notification = false;                  }
        { command = "picom -b";                                                                           notification = false;                  }
        { command = "nm-applet";                                                                          notification = false;                  }
        { command = polkitAgent;                                                                          notification = false;                  }
        { command = "xset s 600 600 && xset +dpms && xset dpms 600 900 1200";                            notification = false;                  }
        { command = "xss-lock --transfer-sleep-lock -- i3lock -n -i ${lockImage}";                       notification = false;                  }
        { command = "${pkgs.xautolock}/bin/xautolock -time 30 -locker 'systemctl suspend'";              notification = false;                  }
        { command = "emacs --daemon";                                                                     notification = false;                  }
        { command = "thunderbird";                                                                        notification = false;                  }
        { command = "strawberry";                                                                         notification = false;                  }
        { command = "maestral start";                                                                     notification = false;                  }
        # Re-run on every reload so a new stylix.image redraws the wallpaper.
        { command = "feh --no-fehbg --bg-fill ${config.stylix.image}";          always = true;           notification = false;                  }
        { command = "pkill -x autotiling; autotiling";                          always = true;           notification = false;                  }
      ];

      # -------------------------------------------------------------------
      # Bars
      # -------------------------------------------------------------------
      bars = [

        # -------------------------------------------------------------------
        # Top bar — workspace numbers + tray + status modules (right side)
        # -------------------------------------------------------------------
        # extraConfig adds strip_workspace_name to the raw i3bar block, which
        # strips everything after the colon so buttons show only the number.
        {
          position      = "top";
          statusCommand = "${pkgs.i3status-rust}/bin/i3status-rs ${config.xdg.configHome}/i3status-rust/config-right.toml";
          trayOutput    = "primary";
          fonts         = barFont;
          extraConfig   = "strip_workspace_name yes";
          colors        = barColors;
        }

        # -------------------------------------------------------------------
        # Bottom bar — workspace icon/names (left) + now playing (right)
        # -------------------------------------------------------------------
        # workspaceNumbers = false maps to strip_workspace_numbers in i3bar,
        # showing only the icon + label (e.g. "󰆍 Term" not "1:󰆍 Term").
        {
          position         = "bottom";
          statusCommand    = "${pkgs.i3status-rust}/bin/i3status-rs ${config.xdg.configHome}/i3status-rust/config-center.toml";
          workspaceNumbers = false;
          trayOutput       = "none";
          fonts            = barFont;
          colors           = barColors;
        }

      ];
    };
  };
}
