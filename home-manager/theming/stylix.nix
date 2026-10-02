# home-manager/theming/stylix.nix
# Wallpaper, generated base16 palette, fonts, cursor and icon theme.
{ pkgs, ... }: {
  config = {
    stylix = {
      enable = true;

      # Wallpaper is declared directly here; color scheme is generated from it.
      image = ../wallpapers/still_wallpapers/wallhaven-3qrdr6.jpg;
      imageScalingMode = "fit";

      polarity = "dark";
      opacity = {
        applications = 0.8;
      };

      fonts = {
        serif = {
          package = pkgs.nerd-fonts.tinos;
          name = "Tinos Nerd Font";
        };
        sansSerif = {
          package = pkgs.nerd-fonts.overpass;
          name = "Overpass Nerd Font Mono";
        };
        monospace = {
          package = pkgs.cozetteNF;
          name = "CozetteVector Nerd Font Mono";
        };
        emoji = {
          package = pkgs.noto-fonts-color-emoji;
          name = "Noto Color Emoji";
        };
      };

      # buuf icons for GTK apps in both sessions. Stylix passes this to
      # gtk.iconTheme, which writes it to dconf (read by GNOME on Wayland) and to
      # gtk-{3,4}.0/settings.ini (read by GTK apps under i3, where no settings
      # daemon forwards the dconf value).
      icons = {
        enable = true;
        package = pkgs.buuf-icon-theme; # overlay in flake.nix
        dark = "buuf-icon-theme";
      };

      targets = {
        gtk.enable = true;

        # ghostty.nix maps the palette itself; VS Code uses Everforest.
        ghostty.enable = false;
        kitty.enable = true;
        vscode.enable = false;

        # i3 session (desktops/i3): window borders, i3bar and notifications.
        # feh is started by i3 itself; Stylix's feh target only works through
        # xsession.initExtra, which is left off so GNOME's Xorg path is untouched.
        i3.enable = true;
        dunst.enable = true;
        feh.enable = false;

        # Qt apps still pick up the palette.
        qt.enable = true;
        kde.enable = false;
      };
    };

    # GTK/GNOME (Wayland) and Xwayland apps all use this cursor.
    home.pointerCursor = {
      enable = true;
      gtk.enable = true;
      x11.enable = true;
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
      size = 16;
    };
  };
}
