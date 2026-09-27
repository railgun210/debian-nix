# home-manager/desktops/i3/i3status-rust.nix
# i3status-rust replacement for i3status.nix. Mirrors the same modules and
# Stylix-derived colours; the bar statusCommand is set in i3.nix.
{
  config,
  pkgs,
  ...
}: let
  c = config.lib.stylix.colors;

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
    Unit.Description = "Write NVIDIA GPU temperature for i3status-rust";
    Service = {
      ExecStart = "${gpuTempPoller}";
      Restart = "on-failure";
    };
    Install.WantedBy = ["default.target"];
  };

  # xkb-switch must be on PATH so the keyboard_layout block's xkbswitch
  # driver can call it at runtime.
  home.packages = [pkgs.xkb-switch];

  programs.i3status-rust = {
    enable = true;
    bars.default = {
      icons = "awesome6";
      theme = {
        theme = "plain";
        overrides = {
          separator = "  ";
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
          separator_fg = "#${c.base03}";
        };
      };
      blocks = [
        {
          block = "keyboard_layout";
          driver = "xkbswitch";
          format = "󰌌 $layout";
        }
        {
          block = "net";
          format = "󰖩 $signal_strength";
          missing_format = "󰖪 down";
          interval = 5;
        }
        {
          block = "temperature";
          format = " $max°C";
          chip = "k10temp-*";
          inputs = ["Tctl"];
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
          block = "sound";
          driver = "pulseaudio";
          format = " $volume";
          format_muted = "󰖁 muted";
        }
        {
          block = "time";
          format = "$timestamp.datetime(f:'%a %d %b %H:%M')";
          interval = 1;
        }
      ];
    };
  };
}
