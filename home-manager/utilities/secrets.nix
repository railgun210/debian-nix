# home-manager/utilities/secrets.nix
# sops-nix setup shared by every module that declares a secret (ssh.nix,
# retroarch.nix). Secrets are decrypted to ~/.config/sops-nix/secrets/ by the
# sops-nix user service, never into the Nix store. See docs/secrets.md.
{pkgs, ...}: let
  ageKeyFile = "/etc/sops/age/keys.txt";
in {
  sops.age.keyFile = ageKeyFile;

  # CLI for editing secrets/*. Point it at the same key instead of
  # ~/.config/sops/age/keys.txt.
  home.packages = with pkgs; [
    sops
    age
  ];
  home.sessionVariables.SOPS_AGE_KEY_FILE = ageKeyFile;
}
