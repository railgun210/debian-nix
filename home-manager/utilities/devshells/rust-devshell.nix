# home-manager/utilities/devshells/rust-devshell.nix
# Rust development environment
#
# Defines a pinned dev shell derivation and installs a 'rs-dev' script to PATH.
# Usage:
#   $ rs-dev
#   (enters a subshell with pinned Rust tools)
#   $ exit
#   (returns to normal shell)
{pkgs, ...}: let
  rustDevShell = pkgs.mkShell {
    packages = with pkgs; [
      rustc
      cargo
      clippy
      rustfmt
      rust-analyzer
      cargo-edit
    ];
  };
in {
  home.packages = [
    (pkgs.writeShellScriptBin "rs-dev" ''
      # Enter the pinned Rust dev environment
      # Defined in: home-manager/utilities/devshells/rust-devshell.nix
      exec nix-shell ${rustDevShell.drvPath} --command zsh
    '')
  ];
}
