# home-manager/desktops/i3/xborders.nix
# Active-window border highlighting with rounded corners via xborders.
# The border color is pulled from the Stylix palette so it always matches
# whatever i3's focused-window border uses (base0D). border-width matches
# i3's window.border value (3 px). smart-hide-border suppresses the border
# when a window fills the workspace alone.
{
  config,
  pkgs,
  ...
}: let
  c = config.lib.stylix.colors;

  xbordersConfig = pkgs.writeText "xborders.json" (builtins.toJSON {
    border-rgba = "#${c.base0D}ff";
    border-width = 3;
    border-radius = 14;
    border-mode = "outside";
    smart-hide-border = true;
  });
in {
  home.packages = [pkgs.xborders];

  xsession.windowManager.i3.config.startup = [
    {
      command = "pkill -x xborders; sleep 1; ${pkgs.xborders}/bin/xborders -c ${xbordersConfig}";
      always = true;
      notification = false;
    }
  ];
}
