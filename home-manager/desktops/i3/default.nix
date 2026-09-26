# home-manager/desktops/i3/default.nix
# i3 (X11) as an alternate GDM session next to GNOME. Nothing here changes the
# GNOME session: xsession.enable stays off (it would write ~/.xprofile, which
# GDM sources for every Xorg session), so Home Manager only writes the i3,
# i3status, picom and dunst config files plus user services that do nothing
# unless something reads their output.
#
# From apt (see docs/debian-setup.md): i3-wm (GDM session entry), i3lock +
# xss-lock (PAM), picom (GLX on Debian's NVIDIA driver), mate-polkit,
# network-manager-gnome (nm-applet) and blueman. Everything else comes from Nix.
{pkgs, ...}: {
  imports = [
    ./i3.nix
    ./i3status.nix
    ./dmenu.nix
    ./picom.nix
    ./dunst.nix
    ./weather.nix
  ];

  home.packages = with pkgs; [
    feh # wallpaper
    maim # screenshots
    xclip # X11 clipboard
    pamixer # volume keys
    pavucontrol # GUI mixer (Super+Shift+V)
    autotiling # split along the longer side
    brightnessctl # brightness keys
  ];

  # Debian's /etc/gdm3/Xsession sources this for Xorg sessions only (GNOME on
  # Wayland never reads it), so i3 and everything dmenu launches get the Home
  # Manager session variables (XDG_DATA_DIRS, TERMINAL, EDITOR, ...).
  home.file.".xsessionrc".text = ''
    if [ -f "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]; then
      . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
    fi
  '';

  # 96 * 1.7, matching GNOME's text-scaling-factor on the 4K screen. Loaded
  # with xrdb at i3 startup; neither GNOME session reads ~/.Xresources.
  xresources.properties."Xft.dpi" = 163;
}
