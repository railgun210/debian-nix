# home-manager/utilities/doom.nix
# Plain emacs plus the external tools Doom's modules call. Doom itself is
# cloned and synced by hand (see README). nerd-icons' "Symbols Nerd Font Mono"
# is installed by theming/font-settings.nix.
{pkgs, ...}: {
  home.packages = with pkgs; [
    emacs

    # :lang markdown (markdown-preview compiler)
    pandoc

    # :lang sh
    shfmt
    shellcheck

    # :lang web
    html-tidy
    stylelint
    js-beautify
  ];
}
