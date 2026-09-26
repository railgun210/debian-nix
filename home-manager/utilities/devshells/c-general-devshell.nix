# home-manager/utilities/devshells/c-general-devshell.nix
# C/C++ general development environment
#
# Defines a pinned dev shell derivation and installs a 'c-dev' script to PATH.
# Usage:
#   $ c-dev
#   (enters a subshell with pinned C/C++ tools)
#   $ exit
#   (returns to normal shell)
{pkgs, ...}: let
  cDevShell = pkgs.mkShell {
    packages = with pkgs; [
      gcc
      gnumake
      cmake
      gdb
      clang-tools
      valgrind
      pkg-config
    ];
  };
in {
  home.packages = [
    (pkgs.writeShellScriptBin "c-dev" ''
      # Enter the pinned C/C++ dev environment
      # Defined in: home-manager/utilities/devshells/c-general-devshell.nix
      exec nix-shell ${cDevShell.drvPath} --command zsh
    '')
  ];
}
