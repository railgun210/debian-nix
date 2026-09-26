# home-manager/utilities/default.nix
# Utilities shared across desktop configurations.
{...}: {
  imports = [
    ./common-packages.nix
    ./default-apps.nix
    ./devshells
    ./development-tools.nix
    ./doom.nix
    ./ghostty.nix
    ./kitty.nix
    ./retroarch.nix
    ./secrets.nix
    ./ssh.nix
    ./thunderbird.nix
    ./vscode.nix
    ./zsh.nix
  ];
}
