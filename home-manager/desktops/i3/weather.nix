# home-manager/desktops/i3/weather.nix
# Current weather on the bar, e.g. "<cloud icon> 93°F", from wttr.in (no API
# key). A user timer writes ~/.cache/weather.txt every 30 minutes; the
# i3status-rust custom block in i3status-rust.nix reads it (json=true). The
# short_text field carries the FA6 icon byte sequence, colored via pango in the
# format string; text carries the temperature.
{
  config,
  pkgs,
  ...
}: let
  location = "San+Antonio";
  weatherFile = "${config.xdg.cacheHome}/weather.txt";

  weather = pkgs.writeShellApplication {
    name = "weather";
    runtimeInputs = [pkgs.coreutils pkgs.curl];
    text = ''
      # %x is wttr.in's plain-text condition symbol, %t the temperature,
      # %S/%s sunrise and sunset
      out=$(curl -fsS "https://wttr.in/${location}?format=%x+%t+%S+%s&u")
      read -r sym temp sunrise sunset <<<"$out"

      # Font Awesome 6 icon bytes (from awesome6.toml) for day and night.
      case "$sym" in
        o)              day=$'\xef\x86\x85' night=$'\xef\x86\x86' ;;  # sun / moon
        m)              day=$'\xef\x83\x82' night=$'\xef\x9b\x83' ;;  # cloud / cloud-moon
        mm | mmm)       day=$'\xef\x83\x82' night=$'\xef\x9b\x83' ;;  # cloud / cloud-moon
        =)              day=$'\xef\x83\x82' night=$'\xef\x83\x82' ;;  # cloud (fog)
        / | .)          day=$'\xef\x9d\x83' night=$'\xef\x9c\xbc' ;;  # cloud-sun-rain / cloud-moon-rain
        // | ///)       day=$'\xef\x9d\x83' night=$'\xef\x9c\xbc' ;;  # cloud-sun-rain / cloud-moon-rain
        x | x/)         day=$'\xef\x8b\x9c' night=$'\xef\x8b\x9c' ;;  # snowflake
        '*' | '*/' | '**' | '*/*') day=$'\xef\x8b\x9c' night=$'\xef\x8b\x9c' ;;  # snowflake
        '!/' | '/!/' | '*!*') day=$'\xef\x83\xa7' night=$'\xef\x83\xa7' ;;  # bolt
        *)              day=$'\xef\x83\x82' night=$'\xef\x83\x82' ;;  # cloud (default)
      esac

      # Sunrise/sunset come back as local HH:MM:SS, which compare as strings.
      now=$(date +%H:%M:%S)
      if [[ $now > $sunrise && $now < $sunset ]]; then icon=$day; else icon=$night; fi

      printf '{"short_text":"%s","text":"%s"}\n' "$icon" "''${temp#+}" > ${weatherFile}.tmp
      mv ${weatherFile}.tmp ${weatherFile}
    '';
  };
in {
  home.packages = [weather];

  systemd.user.services.weather = {
    Unit.Description = "Refresh the weather for i3status-rust";
    Service = {
      Type = "oneshot";
      ExecStart = "${weather}/bin/weather";
      # Network is often not up yet at login.
      Restart = "on-failure";
      RestartSec = 60;
    };
  };

  systemd.user.timers.weather = {
    Unit.Description = "Refresh the weather every 30 minutes";
    Timer = {
      OnStartupSec = "10s";
      OnUnitActiveSec = "30min";
    };
    Install.WantedBy = ["timers.target"];
  };

}
