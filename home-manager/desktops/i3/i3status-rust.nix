# home-manager/desktops/i3/i3status-rust.nix
{
  config,
  pkgs,
  ...
}:
let
  c = config.lib.stylix.colors;

  weatherFile = "${config.xdg.cacheHome}/weather.txt";
  gpuTempFile = "${config.home.homeDirectory}/.cache/gpu_temp";

  # -------------------------------------------------------------------
  # Shell script helpers
  # -------------------------------------------------------------------

  # Polls NVIDIA GPU temperature every 2 s and writes millidegrees to a
  # tmpfile-then-rename so readers never see a partial write.
  gpuTempPoller = pkgs.writeShellScript "gpu-temp-poller" ''
    mkdir -p "$(dirname ${gpuTempFile})"
    while true; do
      t=$(/usr/bin/nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits | head -n1)
      [ -n "$t" ] && echo "$((t * 1000))" > ${gpuTempFile}.tmp && mv ${gpuTempFile}.tmp ${gpuTempFile}
      sleep 2
    done
  '';

  # Outputs i3status-rust JSON: connected device name (truncated to 12 chars)
  # or a disconnected icon.
  btStatus = pkgs.writeShellScript "bt-status" ''
    line=$(bluetoothctl devices Connected 2>/dev/null | head -1)
    if [ -n "$line" ]; then
      name=$(echo "$line" | cut -d' ' -f3-)
      if [ ''${#name} -gt 12 ]; then
        name=$(printf '%s' "$name" | cut -c1-11)…
      fi
      printf '{"short_text":"\xf3\xb0\x82\xaf","text":"%s"}\n' "$name"
    else
      printf '{"short_text":"\xf3\xb0\x82\xb2","text":"Disconnected"}\n'
    fi
  '';

  # PipeWire's PulseAudio compat layer causes intermittent connection races
  # with i3status-rust's native pulseaudio driver, so we shell out to
  # pamixer directly instead.
  volumeStatus = pkgs.writeShellScript "volume-status" ''
    muted=$(pamixer --get-mute)
    vol=$(pamixer --get-volume)
    if [ "$muted" = true ]; then
      printf '{"short_text":"\xef\x9a\xa9","text":"muted"}\n'
    elif [ "$vol" -lt 34 ]; then
      printf '{"short_text":"\xef\x80\xa6","text":"%d%%"}\n' "$vol"
    elif [ "$vol" -lt 67 ]; then
      printf '{"short_text":"\xef\x80\xa7","text":"%d%%"}\n' "$vol"
    else
      printf '{"short_text":"\xef\x80\xa8","text":"%d%%"}\n' "$vol"
    fi
  '';

  # -------------------------------------------------------------------
  # Now-playing centering pad
  # -------------------------------------------------------------------
  # The music block is right-anchored in the bottom bar. Trailing spaces
  # extend the block leftward, pushing the track text toward center.
  # 3840 px bar, ~9 px/char at 15 pt ≈ 427 cols total.
  # ~110 cols for 10 workspace labels leaves ~317 cols for status.
  # (317 - 30 title) / 2 ≈ 143 trailing spaces to roughly center the track.
  # Increase if text sits right of center; decrease if it disappears (overflow).
  musicCenterPad = builtins.concatStringsSep "" (builtins.genList (_: " ") 100);

  # -------------------------------------------------------------------
  # Shared theme
  # -------------------------------------------------------------------
  # Used by the right bar as-is; the center bar merges this with an
  # empty separator override so no pipes appear around the music block.
  commonTheme = {
    theme = "native";
    overrides = {
      separator    = "|";
      idle_bg      = "#${c.base00}";
      idle_fg      = "#${c.base05}";
      info_bg      = "#${c.base00}";
      info_fg      = "#${c.base05}";
      good_bg      = "#${c.base00}";
      good_fg      = "#${c.base0B}";
      warning_bg   = "#${c.base00}";
      warning_fg   = "#${c.base0A}";
      critical_bg  = "#${c.base00}";
      critical_fg  = "#${c.base08}";
      separator_bg = "#${c.base00}";
      separator_fg = "#${c.base02}";
    };
  };

in
{
  systemd.user.services.gpu-temp = {
    Unit.Description = "Write NVIDIA GPU temperature for i3status-rust";
    Service = {
      ExecStart = "${gpuTempPoller}";
      Restart   = "on-failure";
    };
    Install.WantedBy = [ "default.target" ];
  };

  # xkb-switch must be on PATH: the custom keyboard block shells out to it.
  home.packages = [ pkgs.xkb-switch ];

  programs.i3status-rust = {
    enable = true;

    bars = {

      # -------------------------------------------------------------------
      # Center bar — now playing (bottom bar, right side)
      # -------------------------------------------------------------------
      # Separator is stripped so no pipes appear around the music block.
      # musicCenterPad trailing spaces push the text toward horizontal center.
      center = {
        icons         = "awesome6";
        theme         = "plain";
        settings.theme = {
          theme    = "native";
          overrides = commonTheme.overrides // {
            separator = "";
          };
        };
        blocks = [
          {
            block  = "music";
            format = "{ $title.str(max_w:30){ - $artist.str(max_w:20)|}|}${musicCenterPad}";
            click  = [
              { button = "left";   action = "play_pause"; }
              { button = "right";  action = "next";       }
              { button = "middle"; action = "prev";       }
            ];
          }
        ];
      };

      # -------------------------------------------------------------------
      # Right bar — status modules (top bar, right side)
      # -------------------------------------------------------------------
      right = {
        icons          = "awesome6";
        theme          = "plain";
        settings.theme = commonTheme;
        blocks = [

          # Weather
          {
            block    = "custom";
            command  = "[ -f ${weatherFile} ] && grep -q '^{' ${weatherFile} && cat ${weatherFile} || echo '{\"short_text\":\"\",\"text\":\"?\"}'";
            json     = true;
            format   = "<span color='#${c.base02}'>$short_text</span> $text";
            interval = 60;
            click    = [ { button = "left"; cmd = "xdg-open 'https://wttr.in'"; } ];
          }

          # Keyboard layout
          {
            block    = "custom";
            command  = "xkb-switch";
            format   = "<span color='#${c.base02}'>󰌌 </span>$text";
            interval = 1;
            click    = [ { button = "left"; cmd = "xkb-switch -n"; update = true; } ];
          }

          # Network
          {
            block          = "net";
            format         = "<span color='#${c.base02}'>󰖩 </span>$signal_strength";
            missing_format = "<span color='#${c.base02}'>󰖪 </span>down";
            interval       = 5;
            click          = [ { button = "left"; cmd = "nm-connection-editor"; } ];
          }

          # Bluetooth
          {
            block    = "custom";
            command  = "${btStatus}";
            json     = true;
            format   = "<span color='#${c.base02}'>$short_text</span> $text";
            interval = 5;
            click    = [ { button = "left"; cmd = "blueman-manager"; } ];
          }

          # CPU temperature
          {
            block    = "temperature";
            format   = "<span color='#${c.base02}'>󰻠 </span>$max.eng()C";
            chip     = "k10temp-*";
            inputs   = [ "Tctl" ];
            good     = 0;
            idle     = 60;
            info     = 70;
            warning  = 85;
            interval = 5;
          }

          # GPU temperature (polled by the gpu-temp systemd service)
          {
            block    = "custom";
            command  = "[ -f ${gpuTempFile} ] && awk '{printf \"%.0f\", $1/1000}' ${gpuTempFile} || echo '?'";
            format   = "<span color='#${c.base02}'>󰢮 </span>$text°C";
            interval = 2;
          }

          # Disk — root
          {
            block     = "disk_space";
            path      = "/";
            format    = "<span color='#${c.base02}'>󰋊 </span>/ $available";
            info_type = "available";
            warning   = 20.0;
            alert     = 10.0;
          }

          # Disk — home
          {
            block     = "disk_space";
            path      = "/home";
            format    = "<span color='#${c.base02}'>󰋊 </span>/home $available";
            info_type = "available";
            warning   = 20.0;
            alert     = 10.0;
          }

          # Volume
          {
            block    = "custom";
            command  = "${volumeStatus}";
            json     = true;
            format   = "<span color='#${c.base02}'>$short_text</span> $text";
            interval = 1;
            click    = [
              { button = "left";       cmd = "pavucontrol";   }
              { button = "right";      cmd = "pamixer -t";    update = true; }
              { button = "wheel_up";   cmd = "pamixer -i 5";  update = true; }
              { button = "wheel_down"; cmd = "pamixer -d 5";  update = true; }
            ];
          }

          # Clock
          {
            block    = "time";
            format   = "<span color='#${c.base02}'>$icon </span>$timestamp.datetime(f:'%a %d %b %H:%M')";
            interval = 1;
            click    = [ { button = "left"; cmd = "thunderbird -calendar"; } ];
          }

        ];
      };

    };
  };
}
