# home-manager/desktops/i3/i3status.nix
# Status line for the stock i3bar (the bar itself is defined in i3.nix).
# Stylix has no i3status target, so the good/degraded/bad colours come from
# the Stylix palette. They only apply to modules in one of those states;
# everything else uses the bar's `statusline` colour.
{
  config,
  pkgs,
  ...
}: let
  c = config.lib.stylix.colors;

  # The proprietary NVIDIA driver exposes no hwmon sensor, so a user service
  # polls nvidia-smi and writes millidegrees to a file that i3status's
  # cpu_temperature module can read like any other sensor.
  gpuTempFile = "${config.home.homeDirectory}/.cache/gpu_temp";
  gpuTempPoller = pkgs.writeShellScript "gpu-temp-poller" ''
    mkdir -p "$(dirname ${gpuTempFile})"
    while true; do
      t=$(/usr/bin/nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits | head -n1)
      [ -n "$t" ] && echo "$((t * 1000))" > ${gpuTempFile}.tmp && mv ${gpuTempFile}.tmp ${gpuTempFile}
      sleep 2
    done
  '';
in {
  systemd.user.services.gpu-temp = {
    Unit.Description = "Write NVIDIA GPU temperature for i3status";
    Service = {
      ExecStart = "${gpuTempPoller}";
      Restart = "on-failure";
    };
    Install.WantedBy = ["default.target"];
  };

  programs.i3status = {
    enable = true;
    enableDefault = false;

    general = {
      colors = true;
      output_format = "i3bar";
      interval = 1;
      color_good = "#${c.base0B}";
      color_degraded = "#${c.base0A}";
      color_bad = "#${c.base08}";
    };

    modules = {
      "wireless _first_" = {
        position = 1;
        settings = {
          format_up = "󰖩%quality";
          format_down = "󰖪down";
        };
      };
      "cpu_temperature 0" = {
        position = 4;
        settings = {
          format = " %degrees°C";
          max_threshold = 85;
          path = "/sys/devices/pci0000:00/0000:00:18.3/hwmon/hwmon*/temp1_input";
        };
      };
      "cpu_temperature 1" = {
        position = 5;
        settings = {
          format = "󰢮 %degrees°C";
          max_threshold = 80;
          path = gpuTempFile;
        };
      };
      "disk /" = {
        position = 6;
        settings.format = "󰋊 %avail";
      };
      "volume master" = {
        position = 7;
        settings = {
          format = " %volume";
          format_muted = "󰖁 muted";
          device = "pulse";
        };
      };
      "tztime local" = {
        position = 8;
        settings.format = "%a %d %b %H:%M";
      };
    };
  };
}
