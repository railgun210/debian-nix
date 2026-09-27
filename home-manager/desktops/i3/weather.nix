# home-manager/desktops/i3/weather.nix
# Current weather on the bar, e.g. "<cloud icon> 93°F", from wttr.in (no API
# key). A user timer writes ~/.cache/weather.txt every 30 minutes; the
# i3status-rust custom block in i3status-rust.nix reads it. The icons are
# Nerd Font glyphs (with night variants), which the bar font already has.
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

      # Nerd Font glyphs for day and night, with the glyph itself at the end
      # of each comment.
      case "$sym" in
        # sunny: nf-weather-day_sunny (U+E30D)  / nf-md-weather_night (U+F0594) 󰖔
        o) day=$'\xee\x8c\x8d' night=$'\xf3\xb0\x96\x94' ;;
        # partly cloudy: nf-weather-day_cloudy (U+E302)  / nf-weather-night_alt_partly_cloudy (U+E379) 
        m) day=$'\xee\x8c\x82' night=$'\xee\x8d\xb9' ;;
        # cloudy: nf-weather-cloudy (U+E312)  / nf-weather-night_alt_cloudy (U+E37E) 
        mm | mmm) day=$'\xee\x8c\x92' night=$'\xee\x8d\xbe' ;;
        # fog: nf-weather-fog (U+E313)  / nf-weather-night_fog (U+E346) 
        =) day=$'\xee\x8c\x93' night=$'\xee\x8d\x86' ;;
        # light rain / showers: nf-weather-showers (U+E319)  / nf-weather-night_alt_showers (U+E326) 
        / | .) day=$'\xee\x8c\x99' night=$'\xee\x8c\xa6' ;;
        # heavy rain: nf-weather-rain (U+E318)  / nf-weather-night_alt_rain (U+E325) 
        // | ///) day=$'\xee\x8c\x98' night=$'\xee\x8c\xa5' ;;
        # sleet: nf-weather-sleet (U+E3AD)  / nf-weather-night_alt_sleet (U+E3AC) 
        x | x/) day=$'\xee\x8e\xad' night=$'\xee\x8e\xac' ;;
        # snow: nf-weather-snow (U+E31A)  / nf-weather-night_alt_snow (U+E327) 
        '*' | '*/' | '**' | '*/*') day=$'\xee\x8c\x9a' night=$'\xee\x8c\xa7' ;;
        # thunder: nf-weather-thunderstorm (U+E31D)  / nf-weather-night_alt_thunderstorm (U+E32A) 
        '!/' | '/!/' | '*!*') day=$'\xee\x8c\x9d' night=$'\xee\x8c\xaa' ;;
        # unknown: nf-weather-na (U+E374)  / nf-weather-na (U+E374) 
        *) day=$'\xee\x8d\xb4' night=$'\xee\x8d\xb4' ;;
      esac

      # Sunrise/sunset come back as local HH:MM:SS, which compare as strings.
      now=$(date +%H:%M:%S)
      if [[ $now > $sunrise && $now < $sunset ]]; then icon=$day; else icon=$night; fi

      echo "$icon ''${temp#+}" > ${weatherFile}.tmp
      mv ${weatherFile}.tmp ${weatherFile}
    '';
  };
in {
  # The icon font comes from theming/font-settings.nix.
  home.packages = [weather];

  systemd.user.services.weather = {
    Unit.Description = "Refresh the weather for i3status";
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
