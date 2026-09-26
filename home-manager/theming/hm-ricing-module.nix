# home-manager/theming/hm-ricing-module.nix
# hm-ricing-mode can swap Home Manager's read-only config for an editable copy
# while ricing. Right now it only covers fastfetch.
{...}: {
  programs.hm-ricing-mode = {
    enable = true;
    apps = {
      fastfetch.dest_dir = ".config/fastfetch";
    };
  };
}
