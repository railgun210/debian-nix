# home-manager/utilities/development-tools.nix
# Development tools and configurations
{pkgs, ...}: {
  # Development packages
  home.packages = with pkgs; [
    # Rust
    cargo
    rustc

    uv # Fast Python package manager
    ruff # Python linter

    # JavaScript/Node
    nodejs

    # C/C++
    gcc
    gnumake
    cmake
    gdb
    lldb
    clang-tools

    # Nix tools
    nixfmt
    nil # Nix LSP

    # General development
    tmux # Terminal multiplexer
    opencode # Code editor for vibing-out
    claude-code # Anthropic's Claude Code CLI
  ];

  # Per-directory environments (`use flake` in .envrc); installs direnv and
  # hooks it into zsh.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
