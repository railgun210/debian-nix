# home-manager/utilities/retroarch.nix
# RetroArch retro game emulation + RetroAchievements
{
  lib,
  pkgs,
  ...
}: {
  home.packages = [
    # RetroArch — retro game emulation.
    # nixpkgs has no `programs.retroarch` module, so we wrap `retroarch-bare`.
    # `cores` bundles the libretro cores into the wrapper. All configuration is
    # managed by RetroArch itself via ~/.config/retroarch/retroarch.cfg (the
    # in-app menu / config file); no declarative settings are injected.
    (pkgs.retroarch-bare.wrapper {
      cores = with pkgs.libretro; [
        mesen # NES
        bsnes-hd # SNES (HD mode / supersampling)
        snes9x # SNES (fallback core)
        mupen64plus # Nintendo 64
        beetle-psx-hw # PlayStation 1
        pcsx2 # PlayStation 2
        dolphin # GameCube / Wii
        mgba # Game Boy / GBA
        flycast # Dreamcast
        beetle-saturn # Sega Saturn
      ];
    })
  ];

  # RetroAchievements account credentials.
  # These must never end up in the nix store, so they come from sops like the
  # SSH key (see ssh.nix). Decrypted to ~/.config/sops-nix/secrets/ at runtime
  # by the sops-nix user service, then seeded into retroarch.cfg below.
  sops.secrets = {
    retroachievements-username.sopsFile = ../../secrets/secrets.yaml;
    retroachievements-password.sopsFile = ../../secrets/secrets.yaml;
  };

  home.activation = {
    # Seed per-core upscaling into retroarch-core-options.cfg, but ONLY if the
    # file does not exist yet (seed-if-absent). This gives a great first-run
    # experience without ever clobbering tweaks you make in the in-game
    # Quick Menu -> Options. Unknown keys are dropped harmlessly by cores that
    # don't use them.
    seedRetroArchCoreOptions = lib.hm.dag.entryAfter ["writeBoundary"] ''
      CORE_OPTIONS="$HOME/.config/retroarch/retroarch-core-options.cfg"
      if [[ ! -e "$CORE_OPTIONS" ]]; then
        mkdir -p "$(dirname "$CORE_OPTIONS")"
        for line in \
          'beetle_psx_hw_internal_resolution = "4x"' \
          'mupen64plus-next-ScreenSize = "6"' \
          'pcsx2_Internal_Resolution = "4x"' \
          'dolphin_InternalResolution = "4x"' \
          'flycast_rendering_resolution = "1440x1440"' \
          'beetle_saturn_resolution = "6"' \
          'bsnes_hd_supersampling = "true"'
        do
          echo "$line"
        done > "$CORE_OPTIONS"
      fi
    '';

    # BIOS files are intentionally user-provided. Downloading ROM firmware
    # during activation is non-reproducible, unverified, and may be illegal
    # depending on the source and jurisdiction.
    ensureRetroArchBiosDirectory = lib.hm.dag.entryAfter ["writeBoundary"] ''
      mkdir -p "$HOME/Emulation/bios/pcsx2/bios"
    '';

    # Seed the RetroAchievements credentials from sops into retroarch.cfg,
    # since RetroArch reads these two keys from that file. Guarded so it only
    # runs once the sops-nix service has decrypted the secrets, and never
    # duplicates keys the UI may already have written.
    # Caveat: if the sops service hasn't decrypted yet at switch time, just
    # re-run the switch after login — this is idempotent.
    seedRetroArchCheevos = lib.hm.dag.entryAfter ["writeBoundary"] ''
      RA_CFG="$HOME/.config/retroarch/retroarch.cfg"
      USER_FILE="$HOME/.config/sops-nix/secrets/retroachievements-username"
      PASS_FILE="$HOME/.config/sops-nix/secrets/retroachievements-password"
      if [[ -f "$USER_FILE" && -f "$PASS_FILE" ]]; then
        mkdir -p "$(dirname "$RA_CFG")"
        [[ -e "$RA_CFG" ]] || touch "$RA_CFG"
        chmod 600 "$RA_CFG"

        escape_cfg_value() {
          local value="$1"
          value="''${value//\\/\\\\}"
          value="''${value//\"/\\\"}"
          value="''${value//$'\n'/\\n}"
          printf '%s' "$value"
        }

        USER_VALUE="$(escape_cfg_value "$(<"$USER_FILE")")"
        PASS_VALUE="$(escape_cfg_value "$(<"$PASS_FILE")")"
        TMP_CFG="$(mktemp "''${RA_CFG}.XXXXXX")"
        trap 'rm -f "$TMP_CFG"' EXIT

        while IFS= read -r line || [[ -n "$line" ]]; do
          case "$line" in
            cheevos_username\ =\ *) printf 'cheevos_username = "%s"\n' "$USER_VALUE" ;;
            cheevos_password\ =\ *) printf 'cheevos_password = "%s"\n' "$PASS_VALUE" ;;
            *) printf '%s\n' "$line" ;;
          esac
        done < "$RA_CFG" > "$TMP_CFG"

        grep -q '^cheevos_username = ' "$TMP_CFG" || printf 'cheevos_username = "%s"\n' "$USER_VALUE" >> "$TMP_CFG"
        grep -q '^cheevos_password = ' "$TMP_CFG" || printf 'cheevos_password = "%s"\n' "$PASS_VALUE" >> "$TMP_CFG"
        chmod 600 "$TMP_CFG"
        mv "$TMP_CFG" "$RA_CFG"
        trap - EXIT
      fi
    '';
  };
}
