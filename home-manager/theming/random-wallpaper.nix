# home-manager/theming/random-wallpaper.nix
# Daily random wallpaper from wallpapers/still_wallpapers.
#
# Every wallpaper becomes a Home Manager specialisation that only overrides
# stylix.image, so Stylix generates each palette at build time exactly as with
# a hand-picked `image`. A daily timer activates a random specialisation; no
# rebuild happens at runtime.
#
# Manual control:  random-wallpaper        re-apply today's pick
#                  random-wallpaper --new  pick another one now
{
  config,
  lib,
  pkgs,
  ...
}: let
  wallpaperDir = ../wallpapers/still_wallpapers;

  # "wallhaven-3qrdr6.jpg" -> { "wallhaven-3qrdr6" = <path>; }
  wallpapers = lib.mapAttrs' (file: _:
    lib.nameValuePair
    (lib.head (builtins.match "(.*)\\.[^.]*" file))
    (wallpaperDir + "/${file}"))
  (lib.filterAttrs (_: type: type == "regular") (builtins.readDir wallpaperDir));

  # Written by the base generation's activation; also a GC root, so the base
  # (and every specialisation under it) survives while a specialisation is the
  # active Home Manager generation.
  stateDir = "${config.xdg.stateHome}/random-wallpaper";

  # Must not reference anything palette-dependent: it has to be byte-identical
  # in every specialisation, or sd-switch would restart the running service.
  randomWallpaper = pkgs.writeShellApplication {
    name = "random-wallpaper";
    runtimeInputs = [pkgs.coreutils];
    text = ''
      state=${lib.escapeShellArg stateDir}
      base=$(readlink -e "$state/base") || {
        echo "No base generation recorded; run home-manager switch first." >&2
        exit 1
      }
      specs="$base/specialisation"
      today=$(date +%F)
      current=$(cat "$state/current" 2>/dev/null || true)

      if [[ ''${1:-} == --new || $(cat "$state/date" 2>/dev/null || true) != "$today" \
            || -z $current || ! -e $specs/$current ]]; then
        # Avoid picking the same wallpaper twice in a row.
        choices=()
        for spec in "$specs"/*; do
          [[ ''${spec##*/} == "$current" ]] || choices+=("''${spec##*/}")
        done
        [[ ''${#choices[@]} -gt 0 ]] || choices=("$current")
        current=''${choices[RANDOM % ''${#choices[@]}]}
        echo "$current" > "$state/current"
        echo "$today" > "$state/date"
      elif [[ $(readlink -e "$specs/$current") == \
              $(readlink -e "$HOME/.local/state/home-manager/gcroots/current-home" || true) ]]; then
        exit 0 # today's pick is already active
      fi

      echo "Activating wallpaper $current"
      # HM's activation needs nix-env/nix-store from the Nix install.
      PATH="$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:$PATH" \
        exec "$specs/$current/activate"
    '';
  };
in {
  config = {
    specialisation = lib.mapAttrs (_: image: {
      configuration.stylix.image = lib.mkForce image;
    })
    wallpapers;

    home.packages = [randomWallpaper];

    systemd.user.services.random-wallpaper = {
      Unit.Description = "Switch to a random Stylix wallpaper specialisation";
      Service = {
        Type = "oneshot";
        ExecStart = lib.getExe randomWallpaper;
      };
    };

    systemd.user.timers.random-wallpaper = {
      Unit.Description = "Pick a new random wallpaper every day";
      Timer = {
        OnCalendar = "daily";
        Persistent = true; # catch up if the machine was off at midnight
        # Also fire shortly after login and after each `home-manager switch`
        # (the base activation restarts this timer), once that switch is done.
        OnActiveSec = "15s";
      };
      Install.WantedBy = ["timers.target"];
    };

    # Only in the base generation (specialisations have specialisation = {}):
    # record it for the script, then hand back to today's wallpaper, since a
    # plain switch lands on the default stylix.image.
    home.activation.randomWallpaper = lib.mkIf (config.specialisation != {}) (
      lib.hm.dag.entryAfter ["reloadSystemd"] ''
        run mkdir -p ${lib.escapeShellArg stateDir}
        run --silence nix-store --realise "$newGenPath" --add-root ${lib.escapeShellArg "${stateDir}/base"}
        if [[ -z ''${DRY_RUN:-} ]]; then
          env XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" \
            ${dirOf config.systemd.user.systemctlPath}/systemctl --user restart random-wallpaper.timer || true
        fi
      ''
    );
  };
}
