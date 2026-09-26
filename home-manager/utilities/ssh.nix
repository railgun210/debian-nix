# home-manager/utilities/ssh.nix
# GitHub SSH key from sops. The public half is decrypted too, to
# ~/.config/sops-nix/secrets/github-ssh-key-pub, for pasting into GitHub.
{config, ...}: {
  sops.secrets = {
    github-ssh-key = {
      sopsFile = ../../secrets/github-ssh-key.age;
      format = "binary";
    };
    github-ssh-key-pub = {
      sopsFile = ../../secrets/github-ssh-key.pub;
      format = "binary";
    };
  };

  # Add future hosts as matchBlocks here.
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks."github.com" = {
      identityFile = config.sops.secrets.github-ssh-key.path;
      identitiesOnly = true;
    };
  };
}
