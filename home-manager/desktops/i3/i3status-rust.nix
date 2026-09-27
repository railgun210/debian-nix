# home-manager/desktops/i3/i3status-rust.nix
# i3status-rust replacement for i3status.nix. Mirrors the same modules and
# Stylix-derived colours; the bar statusCommand is set in i3.nix.
{
  config,
  pkgs,
  ...
}:
let
  c = config.lib.stylix.colors;

  weatherFile = "${config.xdg.cacheHome}/weather.txt";
  gpuTempFile = "${config.home.homeDirectory}/.cache/gpu_temp";

  gpuTempPoller = pkgs.writeShellScript "gpu-temp-poller" ''
    mkdir -p "$(dirname ${gpuTempFile})"
    while true; do
      t=$(/usr/bin/nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits | head -n1)
      [ -n "$t" ] && echo "$((t * 1000))" > ${gpuTempFile}.tmp && mv ${gpuTempFile}.tmp ${gpuTempFile}
      sleep 2
    done
  '';

  btStatus = pkgs.writeShellScript "bt-status" ''
    line=$(bluetoothctl devices Connected 2>/dev/null | head -1)
    if [ -n "$line" ]; then
      name=$(echo "$line" | cut -d' ' -f3-)
      if [ ''${#name} -gt 12 ]; then
        name=$(printf '%s' "$name" | cut -c1-11)…
      fi
      printf '\xf3\xb0\x82\xaf %s\n' "$name"
    else
      printf '\xf3\xb0\x82\xb2\n'
    fi
  '';

  # Used by the sound custom block. PipeWire's PulseAudio compat layer causes
  # intermittent connection races with i3status-rust's native pulseaudio driver,
  # so we shell out to pamixer directly instead.
  volumeStatus = pkgs.writeShellScript "volume-status" ''
    muted=$(pamixer --get-mute)
    vol=$(pamixer --get-volume)
    if [ "$muted" = true ]; then
      printf '\xef\x9a\xa9 muted\n'
    elif [ "$vol" -lt 34 ]; then
      printf '\xef\x80\xa6 %d%%\n' "$vol"
    elif [ "$vol" -lt 67 ]; then
      printf '\xef\x80\xa7 %d%%\n' "$vol"
    else
      printf '\xef\x80\xa8 %d%%\n' "$vol"
    fi
  '';
in
{
  systemd.user.services.gpu-temp = {
    Unit.Description = "Write NVIDIA GPU temperature for i3status-rust";
    Service = {
      ExecStart = "${gpuTempPoller}";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "default.target" ];
  };

  # xkb-switch must be on PATH: the custom keyboard block shells out to it,
  # and the i3 Alt+Shift keybinding in i3.nix also calls it.
  home.packages = [ pkgs.xkb-switch ];

  programs.i3status-rust = {
    enable = true;
    bars.default = {
      icons = "awesome6";
      theme = "plain";
      settings.theme = {
        theme = "native";
        overrides = {
          separator = "|";
          idle_bg = "#${c.base00}";
          idle_fg = "#${c.base05}";
          info_bg = "#${c.base00}";
          info_fg = "#${c.base05}";
          good_bg = "#${c.base00}";
          good_fg = "#${c.base0B}";
          warning_bg = "#${c.base00}";
          warning_fg = "#${c.base0A}";
          critical_bg = "#${c.base00}";
          critical_fg = "#${c.base08}";
          separator_bg = "#${c.base00}";
          separator_fg = "#${c.base02}";
        };
      };
      blocks = [
        {
          block = "custom";
          command = "[ -f ${weatherFile} ] && cat ${weatherFile} || echo '?'";
          format = "$text";
          interval = 60;
          click = [
            {
              button = "left";
              cmd = "xdg-open 'https://wttr.in'";
            }
          ];
        }
        {
          block = "custom";
          command = "xkb-switch";
          format = "󰌌 $text";
          interval = 1;
          click = [
            {
              button = "left";
              cmd = "xkb-switch -n";
              update = true;
            }
          ];
        }
        {
          block = "net";
          format = "󰖩 $signal_strength";
          missing_format = "󰖪 down";
          interval = 5;
          click = [
            {
              button = "left";
              cmd = "nm-connection-editor";
            }
          ];
        }
        {
          block = "custom";
          command = "${btStatus}";
          format = "$text";
          interval = 5;
          click = [
            {
              button = "left";
              cmd = "blueman-manager";
            }
          ];
        }
        {
          block = "temperature";
          format = "󰻠 $max.eng()C";
          chip = "k10temp-*";
          inputs = [ "Tctl" ];
          good = 0;
          idle = 60;
          info = 70;
          warning = 85;
          interval = 5;
        }
        {
          block = "custom";
          command = "[ -f ${gpuTempFile} ] && awk '{printf \"%.0f\", $1/1000}' ${gpuTempFile} || echo '?'";
          format = "󰢮 $text°C";
          interval = 2;
        }
        {
          block = "disk_space";
          path = "/";
          format = "󰋊 $available";
          info_type = "available";
          warning = 20.0;
          alert = 10.0;
        }
        {
          block = "custom";
          command = "${volumeStatus}";
          format = "$text";
          interval = 1;
          click = [
            {
              button = "left";
              cmd = "pavucontrol";
            }
            {
              button = "right";
              cmd = "pamixer -t";
              update = true;
            }
            {
              button = "wheel_up";
              cmd = "pamixer -i 5";
              update = true;
            }
            {
              button = "wheel_down";
              cmd = "pamixer -d 5";
              update = true;
            }
          ];
        }
        {
          block = "time";
          format = "$timestamp.datetime(f:'%a %d %b %H:%M')";
          interval = 1;
          click = [
            {
              button = "left";
              cmd = "thunderbird -calendar";
            }
          ];
        }
      ];
    };
  };
}
