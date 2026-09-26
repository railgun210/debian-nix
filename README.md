# railgun's Dotfiles — Debian + Home Manager

A standalone **Home Manager** flake for Debian 13 (Trixie). GNOME Classic on
Wayland (GDM) is the main desktop, with **i3** on X11 as an alternate session.
Everything user-level — shell, terminals, editors, dev tools, GUI apps,
theming, GNOME's settings (via dconf) and the whole i3 setup — is declared in
Nix and applied with one command. The desktop itself, drivers and a few
self-updating apps come from `apt`, Flatpak or their own installers, and
`scripts/bootstrap.sh` installs all of those too.

---

## What's managed by Nix

| Category | What I use |
|----------|-----------|
| Shell | Zsh + Oh-My-Zsh + Powerlevel10k, direnv |
| Terminals | Ghostty (primary), Kitty (backup) |
| Editors | Emacs for Doom, vanilla Neovim, VS Code (Everforest Dark) |
| Theme engine | Stylix — generates a base16 palette from the wallpaper and applies it to GNOME, GTK, Qt, Kitty, Ghostty, i3, dunst and dmenu |
| Icons / cursor | buuf (both sessions, via Stylix → GTK settings + dconf), Adwaita cursor |
| Fonts | Terminess Nerd Font (mono), Overpass Nerd Font (sans), Tinos Nerd Font (serif), Noto Color Emoji |
| GNOME settings | Extensions, keybindings, workspaces, monitor layout, font rendering via `dconf.settings` |
| i3 session | i3, i3status (+ weather and GPU temperature), dmenu launcher and power menu, dunst, picom config, i3lock image |
| Email | Thunderbird |
| Dev tools | Rust, Python (uv, ruff), Node, C/C++, Nix LSP (nil), Claude Code, dev shells |
| Secrets | sops-nix (age) — GitHub SSH key, RetroAchievements login |
| Backups | BorgBackup (manual runs to an external drive) |
| Gaming | RetroArch with cores, Prism Launcher, GOverlay |

## What's managed outside Nix

All of these are installed by `scripts/bootstrap.sh`.

| Category | Source |
|----------|--------|
| GNOME Classic, GDM, shell extensions | `apt` |
| i3 session pieces that need root: `i3-wm`, `i3lock`, `xss-lock`, `picom`, `mate-polkit`, `blueman` | `apt` |
| NVIDIA driver (+ 32-bit libs, DRM modesetting, suspend support) | `apt` (non-free) |
| Firefox ESR, LibreOffice, Steam | `apt` |
| NetworkManager, PipeWire, Bluetooth | `apt` |
| Smile (emoji picker), GDM Settings | Flatpak (Flathub) |
| P3X OneNote | Flatpak bundle from GitHub releases |
| Anki | Anki's official Linux build (`/usr/local`) |
| PIA VPN | PIA's official `.run` installer (`/opt/piavpn`) |
| Doom Emacs + config | git clones in `~/.config/emacs` and `~/.config/doom` |

---

## Quick start

On a fresh Debian Trixie install (tasksel: **standard system utilities** only):

```bash
sudo apt install git
git clone https://github.com/railgun210/debian-nix ~/GitRepos/debian-nix
bash ~/GitRepos/debian-nix/scripts/bootstrap.sh
```

The script asks before each optional part (i3, Steam, NVIDIA, Flatpaks,
Doom, Anki, PIA), prompts for the **sops age private key** and is idempotent,
so it is safe to re-run if something fails partway through. Reboot at the end.

See **[docs/debian-setup.md](docs/debian-setup.md)** for the same steps done by
hand and **[docs/secrets.md](docs/secrets.md)** for the age key.

The clone can live anywhere; `~/GitRepos/debian-nix` is only the default.
Day to day, these zsh commands cover rebuilding, from any directory:

| Command | Does |
|---------|------|
| `nsr` | `home-manager switch --flake <repo>#railgun` |
| `nrt` | `home-manager build` (test the config without switching) |
| `nfu` | `nix flake update` |
| `update` | `nfu && nsr` |
| `dotfiles` | `cd` into the repo |
| `cleanup` | Garbage-collect old generations (user + root) |

They find the repo at run time: `$DOTFILES_DIR` if set, else the clone you're
currently in, else the last location that worked (saved in
`~/.local/state/debian-nix/path`, which `bootstrap.sh` also writes), else
`~/GitRepos/debian-nix`. After moving the repo, run `nsr` once from inside it.

---

## Folder structure

```
debian-nix/
├── flake.nix                       # Standalone home-manager flake (+ checks, formatter)
├── .sops.yaml                      # Which age key sops encrypts secrets for
├── scripts/
│   └── bootstrap.sh                # Rebuilds the whole machine (apt, Flatpak, Nix, ...)
├── secrets/                        # sops-encrypted, safe to commit
│   ├── secrets.yaml                # RetroAchievements login (+ unused wifi/anki keys)
│   ├── github-ssh-key.age          # GitHub SSH private key
│   ├── github-ssh-key.pub          # GitHub SSH public key
│   └── pia.age, weather-api-key.age  # Unused leftovers (see docs/secrets.md)
├── docs/
│
└── home-manager/
    ├── home.nix                    # Entry point: genericLinux + NVIDIA, session vars, git, neovim
    ├── wallpapers/                 # Wallpapers; also linked to ~/Wallpapers/
    │
    ├── theming/                    # Imported first so colours/fonts reach everything
    │   ├── stylix.nix              # Wallpaper, palette, fonts, icons, cursor, targets
    │   ├── font-settings.nix       # fontconfig rendering + symbols font
    │   ├── hm-ricing-module.nix    # Live-editable configs while ricing (fastfetch)
    │   └── fastfetch/              # System info display (logo + modules)
    │
    ├── utilities/                  # Apps and CLI tools, shared by both sessions
    │   ├── common-packages.nix     # Main app list (gimp, vlc, bat, eza, borg, lazygit, ...)
    │   ├── default-apps.nix        # XDG MIME defaults (Nautilus, LibreOffice, JupyterLab)
    │   ├── development-tools.nix   # Compilers, LSPs, direnv, Claude Code
    │   ├── devshells/              # c-dev, py-dev, rs-dev, ml-dev
    │   ├── doom.nix                # emacs + tools Doom's modules call
    │   ├── ghostty.nix             # Primary terminal
    │   ├── kitty.nix               # Backup terminal
    │   ├── retroarch.nix           # RetroArch + cores + RetroAchievements
    │   ├── secrets.nix             # sops-nix key path, sops/age CLIs
    │   ├── ssh.nix                 # SSH config + sops-managed GitHub key
    │   ├── thunderbird.nix         # Email client
    │   ├── vscode.nix              # VS Code, extensions, settings
    │   └── zsh.nix                 # Zsh, Powerlevel10k, aliases
    │
    └── desktops/
        ├── gnome/default.nix       # dconf settings, extensions, keybindings, Wayland env
        └── i3/                     # Alternate i3 (X11) session
            ├── default.nix         # Packages, ~/.xsessionrc, Xft.dpi
            ├── i3.nix              # Keybindings, workspaces, autostart, i3bar
            ├── i3status.nix        # Status line + GPU temperature poller
            ├── weather.nix         # wttr.in weather on the bar
            ├── dmenu.nix           # dmenu-themed, desktop-launcher, powermenu-dmenu
            ├── picom.nix           # Compositor config (picom from apt)
            └── dunst.nix           # Notifications
```

---

## Keybindings

The two sessions share the important keys.

| Key | GNOME | i3 |
|-----|-------|----|
| `Super+t` | Ghostty | Ghostty (also `Super+Enter`) |
| `Super+d` | Run dialog | App launcher (dmenu over .desktop files) |
| `Super+b` | Firefox | Firefox |
| `Super+Shift+e` | Nautilus | Nautilus |
| `Super+1..0` | Workspace 1–10 (add Shift to move the window) | same |
| `Super+q` | Close window | Close window |
| `Super+Shift+a` | Anki | Anki |
| `Super+Shift+.` | Smile emoji picker | Smile emoji picker |
| `Super+Shift+s` | Screenshot window | — |
| `Super+s` | — | Screenshot a region to the clipboard |
| `Super+j/k/l/;` | — | Focus left/down/up/right (add Shift to move) |
| `Super+Shift+[` / `]` | — | Move window to previous / next workspace |
| `Super+r` | — | Resize mode |
| `Super+x` | — | Lock (i3lock with the wallpaper) |
| `Super+Shift+x` | — | Power menu (Shutdown / Restart / Suspend / Lock / Logout) |
| `Super+Shift+v` | — | pavucontrol |
| `Ctrl+Alt+z` | — | Emacs client |

---

## i3 session (alternate)

GNOME stays the default desktop. Pick **i3** from the gear menu on GDM's
login screen to get an X11 i3 session instead. It uses the same Stylix
palette: window borders, i3bar + i3status, dmenu and dunst all recolour when
`stylix.image` in `theming/stylix.nix` changes and `home-manager switch` runs
(i3 reloads itself). GTK apps such as Nautilus get the buuf icons and the
Stylix GTK theme from `~/.config/gtk-{3,4}.0/settings.ini`, since no GNOME
settings daemon runs there.

The bar shows the weather (wttr.in, refreshed every 30 minutes by a user
timer), Wi-Fi, CPU and GPU temperature, free disk space, volume and the time.
Home Manager never sets `xsession.enable`, so nothing it writes is read by
the GNOME session.

---

## Editors

### Doom Emacs

Nix installs `emacs` and the external tools Doom's modules call; Doom itself
is managed by Doom. `bootstrap.sh` clones [doomemacs](https://github.com/doomemacs/doomemacs)
to `~/.config/emacs` and [railgun210/doom-emacs](https://github.com/railgun210/doom-emacs)
to `~/.config/doom`, then runs `doom sync`. `~/.config/emacs/bin` is on `PATH`,
so `doom upgrade` / `doom sync` work from any shell.

### Neovim

A zero-plugin Neovim is always available for quick edits. `EDITOR` and
`VISUAL` both point to `emacsclient`.

### VS Code

Extensions come from nixpkgs plus two from the Marketplace (Ellsp and the
Everforest theme). Proprietary extensions not in nixpkgs can still be
installed from the VS Code UI and live alongside the Nix ones.

---

## Theming (Stylix)

Stylix generates a 16-colour base16 palette from the wallpaper set in
`home-manager/theming/stylix.nix` and applies it to GNOME (wallpaper, dark
mode, fonts), GTK, Qt, Kitty, i3 and dunst. Ghostty, i3status and dmenu read
the same palette directly. VS Code uses
[Everforest Dark](https://marketplace.visualstudio.com/items?itemName=sainnhe.everforest)
and is excluded from Stylix. See [docs/base16-reference.md](docs/base16-reference.md)
for what each slot is for.

| Role | Font |
|------|------|
| Monospace | Terminess Nerd Font Mono (rendered without antialiasing) |
| Sans-serif | Overpass Nerd Font Mono |
| Serif | Tinos Nerd Font |
| Emoji | Noto Color Emoji |

---

## Dev shells

Wrapper scripts that drop you into a pinned environment (`exit` to leave):

| Command | What's in it |
|---------|-------------|
| `c-dev` | gcc, make, cmake, gdb, clang-tools, valgrind, pkg-config |
| `py-dev` | python3 with pip, virtualenv, pytest, numpy; uv, ruff, black |
| `rs-dev` | rustc, cargo, clippy, rustfmt, rust-analyzer, cargo-edit |
| `ml-dev` | Python 3.12 with numpy, pandas, scipy, scikit-learn, matplotlib, seaborn, plotly, JupyterLab |

See [docs/devshells.md](docs/devshells.md) for details and per-project flakes.

---

## Secrets

The GitHub SSH key and RetroAchievements login are encrypted with
[sops](https://github.com/getsops/sops) using an age key and decrypted at
activation to `~/.config/sops-nix/secrets/` — never into the Nix store.
Edit them with:

```bash
sops secrets/secrets.yaml
```

`SOPS_AGE_KEY_FILE` already points at `/etc/sops/age/keys.txt`. See
[docs/secrets.md](docs/secrets.md) for setting up the key on a new machine.

---

## Gaming

Steam comes from `apt` (`steam-installer`, with the NVIDIA 32-bit libs) and
runs Windows games through Proton. RetroArch, Prism Launcher and GOverlay come
from Nix; Nix GL apps reach the NVIDIA driver through
`targets.genericLinux.gpu` in `home.nix`.

RetroArch cores: Mesen (NES), bsnes-hd + snes9x (SNES), mupen64plus (N64),
beetle-psx-hw (PS1), pcsx2 (PS2), Dolphin (GCN/Wii), mGBA (GBA), Flycast
(Dreamcast), beetle-saturn (Saturn). Upscaling defaults are seeded into the
core options once, and the RetroAchievements login is written into
`retroarch.cfg` from sops at every switch. BIOS files go in `~/Emulation/bios/`.

---

## Documentation

| Doc | What's in it |
|-----|-------------|
| [docs/debian-setup.md](docs/debian-setup.md) | Everything `bootstrap.sh` does, step by step by hand |
| [docs/devshells.md](docs/devshells.md) | The dev shells and per-project flakes |
| [docs/secrets.md](docs/secrets.md) | sops + age: keys, editing, adding secrets |
| [docs/base16-reference.md](docs/base16-reference.md) | Base16 colour slot reference for theming |
