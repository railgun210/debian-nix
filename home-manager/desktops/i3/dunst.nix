# home-manager/desktops/i3/dunst.nix
# Notifications for i3. dunst is D-Bus activated only; under GNOME, GNOME
# Shell already owns org.freedesktop.Notifications, so dunst never starts
# there. Colours and font come from Stylix's dunst target.
{...}: {
  services.dunst = {
    enable = true;
    settings.global = {
      origin = "top-right";
      offset = "(20, 60)";
      width = 420;
      frame_width = 2;
      corner_radius = 12;
      padding = 12;
      horizontal_padding = 14;
    };
  };
}
