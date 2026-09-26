# home-manager/theming/font-settings.nix
# fontconfig rendering on top of the fonts declared in stylix.nix.
{
  config,
  pkgs,
  ...
}: let
  mono = config.stylix.fonts.monospace.name;
in {
  # Symbols fallback for terminals and editors ("Symbols Nerd Font Mono", which
  # Doom's nerd-icons also looks for) and the proportional "Symbols Nerd Font"
  # used by the i3 weather icon.
  home.packages = [pkgs.nerd-fonts.symbols-only];

  # enabling fontconfig should regenerate cache when new font packages are added
  fonts.fontconfig = {
    enable = true;
    antialiasing = true;
    # Smooth text with subpixel rendering. "slight" keeps glyph shapes close
    # to the font design ("none" is smoother still; "medium"/"full" snap to the
    # pixel grid and look jagged). "rgb" is the standard horizontal subpixel
    # order; the vertical-* values are only for rotated panels.
    # Keep in sync with dconf "org/gnome/desktop/interface" in desktops/gnome/default.nix.
    hinting = "slight";
    subpixelRendering = "rgb";

    # for terminal and such, prefer monospace font followed by symbol font
    defaultFonts.monospace = [
      mono
      "Symbols Nerd Font Mono"
    ];

    configFile = {
      # Home Manager has no lcdfilter option. The default filter smooths
      # subpixel colour fringing the most.
      lcdfilter = {
        enable = true;
        label = "lcdfilter";
        text = ''
          <fontconfig>
            <match target="font">
              <edit name="lcdfilter" mode="assign">
                <const>lcddefault</const>
              </edit>
            </match>
          </fontconfig>
        '';
      };

      # Render the monospace font (Terminess, a bitmap-style font) crisp:
      # no antialiasing, hinted to the pixel grid.
      status = {
        enable = true;
        label = "cozette-disable-antialiasing";
        text = ''
          <fontconfig>
            <match target="font">
              <test name="family">
                <string>${mono}</string>
              </test>
              <edit name="antialias" mode="assign">
                <bool>false</bool>
              </edit>
              <edit name="hinting" mode="assign">
                <bool>true</bool>
              </edit>
            </match>
          </fontconfig>
        '';
      };
    };
  };
}
