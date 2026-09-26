# home-manager/utilities/common-packages.nix
# Common user packages
{pkgs, ...}: {
  home.packages = with pkgs; [
    # GUI Applications
    (pidgin.override {plugins = [pidginPackages.purple-discord];}) # Discord via Pidgin (no Electron)
    gimp # Image editing
    krita # Digital painting
    xournalpp # Handwritten notes and Org-mode figures
    mate.atril # PDF reader
    picard # Music metadata editor
    prismlauncher # Minecraft launcher
    goverlay # GUI for MangoHud
    vlc # Media player
    celluloid # GTK frontend for mpv
    strawberry # Music player
    qbittorrent # Torrent client
    font-manager # Font inspection and management
    maestral # FOSS Dropbox CLI
    maestral-gui # FOSS Dropbox client
    todoist-electron # Our favorite todo list app
    calibre # Ebook management
    cpu-x # CPU info

    # CLI Tools
    bat # Better cat
    eza # Better ls
    fd # Better find
    ffmpeg # Media conversion
    fzf # Fuzzy finder
    imagemagick # Image manipulation
    librsvg # rsvg-convert (SVG rendering)
    mpv # Video player (also Anki's audio backend)
    killall # Process killer
    ripgrep # Better grep
    stress # CPU stress test
    yt-dlp # YouTube/m3u8 downloader
    base16-shell-preview # Base16 color scheme preview in terminal
    borgbackup # Backups to the external drive (see the mount-dallas-zero alias)

    # Development
    docker_29 # At some point you'll have to manually switch this back to just Docker when it gets updated.
    lazygit # Git TUI

    # Fonts
    cozette # Bitmap font (from the cozette flake input)
  ];
}
