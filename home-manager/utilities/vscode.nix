# home-manager/utilities/vscode.nix
# VSCode configuration with a standalone (non-Stylix) theme
{pkgs, ...}: let
  ellsp = pkgs.vscode-utils.extensionFromVscodeMarketplace {
    name = "Ellsp";
    publisher = "jcs090218";
    version = "0.1.3";
    hash = "sha256-u2gvNxDQJLIWIKF+HhyqQJVfTAZFvzHlwno7wqNXwhA=";
  };

  everforest-theme = pkgs.vscode-utils.extensionFromVscodeMarketplace {
    name = "everforest";
    publisher = "sainnhe";
    version = "0.3.0";
    hash = "sha256-nZirzVvM160ZTpBLTimL2X35sIGy5j2LQOok7a2Yc7U=";
  };
in {
  programs.vscode = {
    enable = true;

    profiles.default = {
      # Extensions
      # Note: Many extensions (especially proprietary ones like GitHub Copilot,
      # MS dotnet tools, and remote extensions) are not packaged in nixpkgs and
      # must be installed manually through the VSCode UI. They will persist fine
      # alongside nix-managed extensions.
      # It's not an exactly perfect system but other than just using Neovim this is the best option.
      extensions = with pkgs.vscode-extensions;
        [
          # Nix
          jnoortheen.nix-ide
          mkhl.direnv

          # Python
          ms-python.python
          ms-python.debugpy
          ms-python.isort
          ms-python.vscode-pylance

          # Rust
          rust-lang.rust-analyzer

          # C/C++
          ms-vscode.cpptools

          # Docker
          ms-azuretools.vscode-docker

          # Jupyter
          ms-toolsai.jupyter

          # Java
          redhat.java
          vscjava.vscode-java-debug
          vscjava.vscode-java-dependency
          vscjava.vscode-java-test
          vscjava.vscode-maven
          vscjava.vscode-gradle

          # Git
          donjayamanne.githistory

          # Vim
          vscodevim.vim

          # Misc
          mechatroner.rainbow-csv
          njpwerner.autodocstring
          shd101wyy.markdown-preview-enhanced
        ]
        ++ [
          ellsp # Emacs Lisp LSP
          everforest-theme
        ];

      userSettings = {
        "workbench.colorTheme" = "Everforest Dark";

        # Window
        "window.newWindowDimensions" = "default";
        "window.restoreWindows" = "none";

        "security.workspace.trust.untrustedFiles" = "open";

        # Editor — font set directly instead of via Stylix's font option
        "editor.fontFamily" = "'Terminess Nerd Font Mono'";
        "editor.fontSize" = 16;
        "editor.formatOnSave" = true;
        "editor.minimap.enabled" = false;
        "editor.renderWhitespace" = "boundary";
        "editor.tabSize" = 2;

        # Nix
        "nix.enableLanguageServer" = true;
        "nix.serverPath" = "nil"; # installed by development-tools.nix

        # Git
        "git.autofetch" = true;
        "git.confirmSync" = false;

        # Vim
        "vim.useSystemClipboard" = true;
        "vim.hlsearch" = true;

        # VS Code draws its own title bar (it runs natively on Wayland via
        # NIXOS_OZONE_WL, see desktops/gnome/default.nix).
        "window.titleBarStyle" = "custom";
      };
    };
  };
}
