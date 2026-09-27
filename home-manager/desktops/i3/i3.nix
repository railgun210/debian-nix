# home-manager/desktops/i3/i3.nix
# Ported from the old Arch i3 config (~/GitRepos/dotfiles/i3). Colours and
# fonts come from Stylix's i3 target; the bar sets its own font and palette
# colours below. The status line it runs is defined in i3status.nix.
{
  config,
  lib,
  pkgs,
  ...
}: let
  mod = "Mod4";
  # Ghostty's shared config keeps its GTK titlebar for GNOME; under i3 the
  # window manager provides borders, so drop the titlebar here.
  term = "ghostty --window-decoration=none";

  # vim-style direction keys, shifted one to the right like the old config
  left = "j";
  down = "k";
  up = "l";
  right = "semicolon";

  ws = toString;
  # Super+1..9 and Super+0 (= workspace 10), same as the GNOME setup
  key = n:
    if n == 10
    then "0"
    else toString n;

  workspaceBindings = lib.listToAttrs (lib.concatMap (n: [
    (lib.nameValuePair "${mod}+${key n}" "workspace ${ws n}")
    (lib.nameValuePair "${mod}+Shift+${key n}" "move container to workspace ${ws n}")
  ]) (lib.range 1 10));

  # i3lock only reads PNG, so convert the Stylix wallpaper at build time.
  lockImage = pkgs.runCommand "i3lock-wallpaper.png" {nativeBuildInputs = [pkgs.imagemagick];} ''
    magick ${config.stylix.image} -resize 3840x2160^ -gravity center -extent 3840x2160 png:$out
  '';

  polkitAgent = "/usr/libexec/polkit-mate-authentication-agent-1";

  c = config.lib.stylix.colors;

  # Bar font. Use a Nerd Font so the i3status module icons render.
  barFont = {
    names = [config.stylix.fonts.monospace.name];
    style = "Regular";
    size = 15.0;
  };

  langStatusWrapper = pkgs.writeShellScript "lang-i3status" ''
    layout_file=$(mktemp /tmp/xkb-layout.XXXXXX)
    ${pkgs.xkb-switch}/bin/xkb-switch > "$layout_file"

    ( ${pkgs.xkb-switch}/bin/xkb-switch -W | while read -r layout; do
      echo "$layout" > "$layout_file"
      pkill -SIGUSR1 i3status
    done ) &
    watcher_pid=$!
    trap 'rm -f "$layout_file"; kill $watcher_pid 2>/dev/null' EXIT

    ${pkgs.i3status}/bin/i3status | {
      read -r header && echo "$header"   # {"version":1}
      read -r open   && echo "$open"     # [
      while read -r line; do
        LG=$(cat "$layout_file")
        prefix=""; data="$line"
        [[ "$line" == ,* ]] && { prefix=","; data=''${line:1}; }
        echo "$prefix$(echo "$data" | ${pkgs.jq}/bin/jq --arg lbl "󰌌 $LG" '[{"full_text":$lbl}] + .')" || exit 1
      done
    }
  '';
in {
  xsession.windowManager.i3 = {
    enable = true;
    config = {
      modifier = mod;
      terminal = term;
      defaultWorkspace = "workspace ${ws 1}";

      gaps = {
        inner = 10;
        outer = 10;
        smartBorders = "on";
      };

      window = {
        border = 3;
        titlebar = false;
        hideEdgeBorders = "none";
        commands = [
          {
            criteria.instance = "floating_term";
            command = "floating enable, resize set 800 600";
          }
          # Smile emoji picker: a normal floating window in the middle of
          # the screen instead of a tile.
          {
            criteria.class = "^smile$";
            command = "floating enable, move position center";
          }
        ];
      };

      assigns = {
        ${ws 4} = [{class = "^vlc$";}];
        ${ws 5} = [{class = "^Strawberry$";}];
        ${ws 6} = [{class = "^steam$";}];
        ${ws 7} = [{class = "^org.mozilla.Thunderbird$";} {class = "^thunderbird$";}];
      };

      keybindings =
        workspaceBindings
        // {
          # Focus / move
          "${mod}+${left}" = "focus left";
          "${mod}+${down}" = "focus down";
          "${mod}+${up}" = "focus up";
          "${mod}+${right}" = "focus right";
          "${mod}+Shift+${left}" = "move left";
          "${mod}+Shift+${down}" = "move down";
          "${mod}+Shift+${up}" = "move up";
          "${mod}+Shift+${right}" = "move right";

          "${mod}+f" = "fullscreen toggle";
          "${mod}+a" = "focus parent";
          "${mod}+space" = "floating toggle";
          "${mod}+Shift+space" = "focus mode_toggle";

          # Workspace cycling
          "${mod}+bracketright" = "workspace next";
          "${mod}+bracketleft" = "workspace prev";
          "${mod}+period" = "workspace next";
          "${mod}+comma" = "workspace prev";
          "${mod}+Tab" = "workspace next";
          "${mod}+Shift+Tab" = "workspace prev";
          "${mod}+Shift+bracketright" = "move container to workspace next; workspace next";
          "${mod}+Shift+bracketleft" = "move container to workspace prev; workspace prev";

          # Launchers
          "${mod}+d" = "exec --no-startup-id desktop-launcher";
          "${mod}+t" = "exec ${term}";
          "${mod}+Return" = "exec ${term}";
          "${mod}+b" = "exec firefox-esr";
          "${mod}+Shift+e" = "exec nautilus";
          "Ctrl+Mod1+z" = "exec emacsclient -c -a ''";
          "${mod}+Shift+a" = "exec anki"; # same key as GNOME; anki is in /usr/local/bin
          "${mod}+Shift+period" = "exec flatpak run it.mijorus.smile"; # emoji picker, same key as GNOME
          "${mod}+s" = "exec --no-startup-id ${pkgs.maim}/bin/maim -s -u | ${pkgs.xclip}/bin/xclip -selection clipboard -t image/png -i";

          # i3 controls
          "${mod}+q" = "kill";
          "${mod}+Shift+c" = "reload";
          "${mod}+Shift+r" = "restart";
          "${mod}+r" = "mode resize";

          # Power menu and lock (xss-lock runs i3lock on lock-session)
          "${mod}+Shift+x" = "exec --no-startup-id powermenu-dmenu";
          "${mod}+x" = "exec --no-startup-id loginctl lock-session";

          # Volume / brightness
          "Ctrl+Mod1+1" = "exec --no-startup-id pamixer -d 10";
          "Ctrl+Mod1+2" = "exec --no-startup-id pamixer -i 10";
          "Ctrl+Mod1+3" = "exec --no-startup-id pamixer -t";
          "${mod}+Shift+v" = "exec --no-startup-id pavucontrol";
          "XF86AudioLowerVolume" = "exec --no-startup-id pamixer -d 5";
          "XF86AudioRaiseVolume" = "exec --no-startup-id pamixer -i 5";
          "XF86AudioMute" = "exec --no-startup-id pamixer -t";
          "XF86MonBrightnessDown" = "exec --no-startup-id brightnessctl set 5%-";
          "XF86MonBrightnessUp" = "exec --no-startup-id brightnessctl set +5%";

          # Language switching (Alt+Left Shift or Alt+Right Shift)
          "Mod1+Shift_L" = "exec --no-startup-id ${pkgs.xkb-switch}/bin/xkb-switch -n";
          "Mod1+Shift_R" = "exec --no-startup-id ${pkgs.xkb-switch}/bin/xkb-switch -n";
        };

      modes.resize = {
        "${left}" = "resize shrink width 10 px or 10 ppt";
        "${down}" = "resize grow height 10 px or 10 ppt";
        "${up}" = "resize shrink height 10 px or 10 ppt";
        "${right}" = "resize grow width 10 px or 10 ppt";
        "Escape" = "mode default";
        "Return" = "mode default";
      };

      startup = [
        # Once per login
        {
          command = "xrdb -merge ~/.Xresources";
          notification = false;
        }
        {
          command = "setxkbmap -layout us,latam";
          always = true;
          notification = false;
        }
        {
          command = "picom -b";
          notification = false;
        }
        {
          command = "nm-applet";
          notification = false;
        }
        {
          command = polkitAgent;
          notification = false;
        }
        {
          command = "xset s 600 600 && xset +dpms && xset dpms 600 900 1200";
          notification = false;
        }
        {
          command = "xss-lock --transfer-sleep-lock -- i3lock -n -i ${lockImage}";
          notification = false;
        }
        {
          command = "emacs --daemon";
          notification = false;
        }
        {
          command = "thunderbird";
          notification = false;
        }
        {
          command = "strawberry";
          notification = false;
        }
        {
          command = "maestral start";
          notification = false;
        }

        # On every reload too, so a new stylix.image redraws the wallpaper.
        {
          command = "feh --no-fehbg --bg-fill ${config.stylix.image}";
          always = true;
          notification = false;
        }
        {
          command = "pkill -x autotiling; autotiling";
          always = true;
          notification = false;
        }
      ];

      # Stock i3bar with its own font and colours from the Stylix palette
      # (Stylix's exportedBarConfig is not merged in). The status line itself
      # is configured in i3status.nix.
      bars = [
        {
          position = "top";
          statusCommand = "${langStatusWrapper}";
          trayOutput = "primary";
          fonts = barFont;
          colors = {
            background = "#${c.base00}";
            statusline = "#${c.base05}"; # default text for all modules
            separator = "#${c.base03}";
            focusedWorkspace = {
              border = "#${c.base0D}";
              background = "#${c.base02}";
              text = "#${c.base05}";
            };
            inactiveWorkspace = {
              border = "#${c.base00}";
              background = "#${c.base00}";
              text = "#${c.base05}";
            };
            urgentWorkspace = {
              border = "#${c.base08}";
              background = "#${c.base0E}";
              text = "#${c.base05}";
            };
          };
        }
      ];
    };
  };
}
