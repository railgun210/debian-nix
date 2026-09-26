# home-manager/utilities/devshells/default.nix
# Import hub for all devshell modules
# Each module installs a wrapper script (c-dev, py-dev, rs-dev, ml-dev) that
# enters a pinned dev environment
{...}: {
  imports = [
    ./c-general-devshell.nix
    ./ml-devshell.nix
    ./python-devshell.nix
    ./rust-devshell.nix
  ];
}
