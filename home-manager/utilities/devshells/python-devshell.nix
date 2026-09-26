# home-manager/utilities/devshells/python-devshell.nix
# Python development environment
#
# Defines a pinned dev shell derivation and installs a 'py-dev' script to PATH.
# Usage:
#   $ py-dev
#   (enters a subshell with pinned Python tools)
#   $ exit
#   (returns to normal shell)
{pkgs, ...}: let
  pythonDevShell = pkgs.mkShell {
    packages = with pkgs; [
      # One interpreter with its libraries, so `python -m pytest` and
      # `import numpy` work (mixing python3 with python312Packages did not).
      (python3.withPackages (ps: [
        ps.pip
        ps.virtualenv
        ps.pytest
        ps.numpy
      ]))
      uv
      ruff
      black
    ];
  };
in {
  home.packages = [
    (pkgs.writeShellScriptBin "py-dev" ''
      # Enter the pinned Python dev environment
      # Defined in: home-manager/utilities/devshells/python-devshell.nix
      exec nix-shell ${pythonDevShell.drvPath} --command zsh
    '')
  ];
}
