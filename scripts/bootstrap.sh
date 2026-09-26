#!/usr/bin/env bash
# bootstrap.sh — Rebuild railgun's Debian Trixie desktop from scratch
#
# Run this on a fresh Debian Trixie install (tasksel: "standard system
# utilities" only) to get back everything: the apt side (GNOME, i3, NVIDIA,
# Steam, ...), Flatpak apps, the apps that ship their own installers (Anki,
# PIA, P3X OneNote), Nix and the full home-manager config. Each optional part
# asks first. The script is idempotent — safe to re-run.

set -euo pipefail

REPO_URL="https://github.com/railgun210/debian-nix"
# Use the clone this script lives in, wherever it is; otherwise clone here.
SCRIPT_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd || true)"
if [[ -n "$SCRIPT_REPO" && -f "$SCRIPT_REPO/flake.nix" && -f "$SCRIPT_REPO/home-manager/home.nix" ]]; then
    REPO_PATH="$SCRIPT_REPO"
else
    REPO_PATH="$HOME/GitRepos/debian-nix"
fi
# Where the zsh commands (nsr, nfu, update, ...) look up the repo; see zsh.nix.
DOTFILES_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/debian-nix/path"
# PIA has no "latest" download link; bump this when a new client is out.
PIA_VERSION="${PIA_VERSION:-3.7.2-08420}"

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${GREEN}[✓]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[!]${RESET} $*"; }
error()   { echo -e "${RED}[✗]${RESET} $*" >&2; }
section() { echo -e "\n${CYAN}${BOLD}━━  $*  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"; }
die()     { error "$*"; exit 1; }

prompt()  {
    # prompt <variable_name> <prompt_text> [default]
    local var="$1" msg="$2" default="${3:-}"
    local display_default=""
    [[ -n "$default" ]] && display_default=" [${default}]"
    echo -en "${BOLD}${msg}${display_default}: ${RESET}"
    # shellcheck disable=SC2229 # reads into the variable named by $var
    read -r "$var"
    # If blank and there's a default, use it
    if [[ -z "${!var}" && -n "$default" ]]; then
        printf -v "$var" '%s' "$default"
    fi
}

# ask <question> — yes/no, defaulting to yes
ask() {
    local reply
    echo -en "${BOLD}$* [Y/n]: ${RESET}"
    read -r reply
    [[ ! "$reply" =~ ^[Nn]$ ]]
}

# apt_install <pkg>... — install only what is missing
apt_install() {
    local missing=() pkg
    for pkg in "$@"; do
        dpkg-query -W -f='${db:Status-Abbrev}' "$pkg" 2>/dev/null | grep -q '^ii' || missing+=("$pkg")
    done
    if [[ ${#missing[@]} -eq 0 ]]; then
        info "Already installed: $*"
        return
    fi
    info "Installing: ${missing[*]}"
    sudo apt-get install -y "${missing[@]}"
}

# github_asset <owner/repo> <regex> — download URL of the latest release asset
github_asset() {
    curl -fsSL "https://api.github.com/repos/$1/releases/latest" \
        | grep -oE '"browser_download_url": *"[^"]+"' \
        | cut -d'"' -f4 \
        | grep -E "$2" \
        | head -n1
}

# ── Banner ────────────────────────────────────────────────────────────────────
echo -e "${CYAN}${BOLD}"
echo "  ┌─────────────────────────────────────────────────┐"
echo "  │  railgun's dotfiles — Debian Trixie bootstrap   │"
echo "  │  apt + Flatpak + Nix + standalone home-manager  │"
echo "  └─────────────────────────────────────────────────┘"
echo -e "${RESET}"
echo "This script will:"
echo "  • Enable contrib/non-free and i386, install the apt packages"
echo "    (GNOME, i3, NVIDIA driver, Steam, ...)"
echo "  • Install Nix (multi-user daemon) and enable flakes"
echo "  • Set up your sops age decryption key"
echo "  • Clone the debian-nix repo and apply the home-manager config"
echo "  • Set zsh as your default shell"
echo "  • Install Flatpak apps, Anki, PIA VPN and P3X OneNote"
echo ""
warn "This modifies your system. Root access (sudo) is required."
echo -en "${BOLD}Continue? [y/N]: ${RESET}"
read -r CONFIRM
[[ "$CONFIRM" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

# ── 1. Preflight ──────────────────────────────────────────────────────────────
section "Preflight checks"

# OS check
if [[ -f /etc/os-release ]]; then
    # shellcheck source=/dev/null
    . /etc/os-release
    if [[ "${ID:-}" != "debian" ]]; then
        warn "This script targets Debian Trixie. Detected: ${PRETTY_NAME:-unknown}"
        echo -en "${BOLD}Continue anyway? [y/N]: ${RESET}"
        read -r OVERRIDE
        [[ "$OVERRIDE" =~ ^[Yy]$ ]] || die "Aborted — unsupported OS."
    else
        info "OS: ${PRETTY_NAME}"
    fi
else
    warn "Cannot determine OS — /etc/os-release not found. Proceeding anyway."
fi

# User check — config is hardcoded to username "railgun"
CURRENT_USER="$(id -un)"
if [[ "$CURRENT_USER" != "railgun" ]]; then
    die "The home-manager config is hardcoded to username 'railgun' and homedir '/home/railgun'.
  You are logged in as '${CURRENT_USER}'.
  Either log in as 'railgun' or create that user first:
    sudo adduser railgun
    sudo usermod -aG sudo railgun"
fi
info "User: $CURRENT_USER"

# Sudo check
if ! sudo -v 2>/dev/null; then
    die "sudo is not available or you have no sudo rights. Make sure '$CURRENT_USER' is in the sudo group."
fi
info "sudo access confirmed"

# ── 2. APT sources and architectures ─────────────────────────────────────────
section "APT sources (contrib, non-free, i386)"

# Trixie's installer only enables main + non-free-firmware; nvidia-driver and
# steam-installer live in non-free/contrib.
if [[ -f /etc/apt/sources.list ]] && grep -qE '^deb .* main non-free-firmware$' /etc/apt/sources.list; then
    sudo sed -i -E '/^deb/ s/ main non-free-firmware$/ main contrib non-free non-free-firmware/' /etc/apt/sources.list
    info "Enabled contrib and non-free in /etc/apt/sources.list"
elif grep -rqsE '^(deb .*|Components:.*) contrib' /etc/apt/sources.list /etc/apt/sources.list.d/; then
    info "contrib and non-free already enabled"
else
    warn "Could not find the Debian lines to extend. Enable contrib and non-free by hand,"
    warn "or the NVIDIA and Steam packages below will have no installation candidate."
fi

# 32-bit libraries for Steam and the NVIDIA 32-bit GL driver
if dpkg --print-foreign-architectures | grep -qx i386; then
    info "i386 architecture already enabled"
else
    sudo dpkg --add-architecture i386
    info "Enabled the i386 architecture"
fi

sudo apt-get update -qq

# Needed by everything below
apt_install curl git xz-utils zstd ca-certificates

# Internet check (now that curl is guaranteed available)
if ! curl -sf --max-time 10 https://nixos.org > /dev/null; then
    die "No internet access — cannot reach nixos.org. Check your connection."
fi
info "Internet connectivity confirmed"

# ── 3. APT packages ───────────────────────────────────────────────────────────
section "APT packages"

# Minimal GNOME Classic on Wayland, the extensions desktops/gnome enables, and
# the desktop basics a "standard utilities only" install lacks.
info "GNOME desktop"
apt_install \
    gdm3 gnome-session gnome-classic gnome-shell-extensions \
    gnome-shell-extension-appindicator gnome-shell-extension-desktop-icons-ng \
    gnome-shell-extension-user-theme gnome-tweaks \
    nautilus gnome-control-center gnome-terminal file-roller loupe papers \
    gnome-system-monitor xdg-desktop-portal-gnome \
    network-manager network-manager-gnome pipewire-audio bluez \
    flatpak gnome-software-plugin-flatpak
sudo systemctl enable gdm3

# Browser and office suite (BROWSER and the Office MIME defaults point here)
info "Apps"
apt_install firefox-esr libreoffice-writer libreoffice-calc libreoffice-impress libreoffice-gnome

# Everyday CLI tools kept outside Nix
info "System tools"
apt_install vim btop apt-file netselect-apt
sudo apt-file update >/dev/null

# GTK2 engine + themes from the old MATE setup (older GTK2 apps still use them)
info "GTK2 themes"
apt_install gtk2-engines-murrine murrine-themes shiki-colors

if ask "Install the i3 session (i3-wm, i3lock, xss-lock, picom, polkit agent, blueman)?"; then
    apt_install i3-wm i3lock xss-lock picom mate-polkit blueman
fi

if ask "Install Steam (steam-installer from contrib)?"; then
    apt_install steam-installer
fi

# ── 4. NVIDIA driver ─────────────────────────────────────────────────────────
section "NVIDIA driver"

NVIDIA_REBOOT=0
if ask "Install the proprietary NVIDIA driver?"; then
    # nvidia-driver-libs:i386: 32-bit GL for Steam (see docs/debian-setup.md)
    apt_install linux-headers-amd64 nvidia-driver nvidia-driver-libs:i386 firmware-misc-nonfree

    # GDM falls back to Xorg without DRM modesetting.
    MODESET_CONF=/etc/modprobe.d/nvidia-drm-modeset.conf
    MODESET_LINE="options nvidia-drm modeset=1 fbdev=1"
    if ! grep -qxF "$MODESET_LINE" "$MODESET_CONF" 2>/dev/null; then
        echo "$MODESET_LINE" | sudo tee "$MODESET_CONF" > /dev/null
        NVIDIA_REBOOT=1
        info "Wrote $MODESET_CONF"
    fi

    # Keep VRAM contents across suspend (used by nvidia-suspend/resume), so
    # Wayland sessions come back from sleep intact.
    PM_CONF=/etc/modprobe.d/nvidia-power-management.conf
    PM_LINE="options nvidia NVreg_PreserveVideoMemoryAllocations=1 NVreg_TemporaryFilePath=/var/tmp"
    if ! grep -qxF "$PM_LINE" "$PM_CONF" 2>/dev/null; then
        echo "$PM_LINE" | sudo tee "$PM_CONF" > /dev/null
        NVIDIA_REBOOT=1
        info "Wrote $PM_CONF"
    fi
    sudo systemctl enable nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service 2>/dev/null || true

    if [[ "$NVIDIA_REBOOT" -eq 1 ]]; then
        sudo update-initramfs -u
    fi

fi

# ── 5. Install Nix ───────────────────────────────────────────────────────────
section "Installing Nix"

NIX_DAEMON_PROFILE="/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"

# A previous run (or a fresh terminal) may have Nix installed but not on PATH
if ! command -v nix &>/dev/null && [[ -f "$NIX_DAEMON_PROFILE" ]]; then
    # shellcheck source=/dev/null
    . "$NIX_DAEMON_PROFILE"
fi

if command -v nix &>/dev/null; then
    info "Nix already installed: $(nix --version)"
elif [[ -d /nix/store ]]; then
    die "/nix exists but 'nix' is not usable (is the nix-daemon running?).
  Try: sudo systemctl restart nix-daemon
  Then open a new terminal and re-run this script."
else
    info "Running the Nix multi-user installer..."
    sh <(curl -L https://nixos.org/nix/install) --daemon < /dev/tty

    if [[ -f "$NIX_DAEMON_PROFILE" ]]; then
        # shellcheck source=/dev/null
        . "$NIX_DAEMON_PROFILE"
    fi

    if ! command -v nix &>/dev/null; then
        die "Nix was installed but 'nix' is not in PATH.
  Open a new terminal and re-run this script — it will pick up where it left off."
    fi
    info "Nix installed: $(nix --version)"
fi

# ── 6. Enable flakes ─────────────────────────────────────────────────────────
section "Enabling Nix flakes"

NIX_CONF="$HOME/.config/nix/nix.conf"
FLAKE_LINE="experimental-features = nix-command flakes"

mkdir -p "$(dirname "$NIX_CONF")"
if grep -qxF "$FLAKE_LINE" "$NIX_CONF" 2>/dev/null; then
    info "Flakes already enabled in $NIX_CONF"
else
    # Drop any earlier experimental-features line (e.g. the old misspelled
    # "nix command flakes") so we don't leave a broken one behind
    if grep -q '^experimental-features' "$NIX_CONF" 2>/dev/null; then
        sed -i '/^experimental-features/d' "$NIX_CONF"
        warn "Replaced an existing experimental-features line in $NIX_CONF"
    fi
    echo "$FLAKE_LINE" >> "$NIX_CONF"
    info "Flakes enabled in $NIX_CONF"
fi

# ── 7. sops age key ───────────────────────────────────────────────────────────
section "Setting up sops age key"

AGE_KEY_DIR="/etc/sops/age"
AGE_KEY_FILE="$AGE_KEY_DIR/keys.txt"

# An age secret key is "AGE-SECRET-KEY-1" + 58 bech32 characters (uppercase)
AGE_KEY_REGEX='^AGE-SECRET-KEY-1[QPZRY9X8GF2TVDW0S3JN54KHCE6MUA7L]{58}$'

# Clean up pasted text: drop terminal escape sequences (bracketed paste), CRs,
# and all whitespace/quotes, then uppercase. One cleaned line per input line.
normalize_age_lines() {
    sed -E 's/\x1b\[[0-9;?]*[~A-Za-z]//g' | tr -d '\r' | sed -E "s/[[:space:]\"']//g" | tr 'a-z' 'A-Z'
}

# Print only the valid secret-key line(s) from stdin
extract_age_keys() {
    normalize_age_lines | grep -E "$AGE_KEY_REGEX" || true
}

# Explain (without echoing the secret) why the input was rejected
diagnose_age_input() {
    local text="$1" line len bad
    if printf '%s\n' "$text" | normalize_age_lines | grep -q '^AGE1'; then
        error "That is the PUBLIC key (age1...). Paste the private one: AGE-SECRET-KEY-1..."
        return
    fi
    line="$(printf '%s\n' "$text" | normalize_age_lines | grep -m1 '^AGE-SECRET-KEY-' || true)"
    if [[ -z "$line" ]]; then
        error "No line starting with AGE-SECRET-KEY- was found in what was pasted."
        return
    fi
    len=${#line}
    bad="$(printf '%s' "${line#AGE-SECRET-KEY-1}" | tr -d 'QPZRY9X8GF2TVDW0S3JN54KHCE6MUA7L' | wc -c)"
    error "Found a key line, but it is ${len} characters (expected 74) with ${bad} invalid character(s)."
    echo "  The key was probably cut off, or extra text got pasted along with it."
}

# Ask the user for a key; sets AGE_KEY_CONTENT. Returns 1 if the input was invalid
# so the caller can ask again instead of exiting.
read_age_key() {
    local method raw="" line path
    echo ""
    echo "How do you want to provide the age private key?"
    echo "  [1] Paste the key content here"
    echo "  [2] Provide the path to an existing key file"
    echo ""
    prompt method "Enter choice" "1"

    case "$method" in
        1)
            echo ""
            echo "Paste your PRIVATE age key (AGE-SECRET-KEY-1..., not the age1... public key)."
            echo "Input is hidden. Press Enter after pasting; an empty line finishes."
            echo ""
            while IFS= read -r -s line; do
                [[ -z "$line" ]] && break
                raw+="$line"$'\n'
                # Stop as soon as a complete valid key has been pasted
                printf '%s\n' "$line" | extract_age_keys | grep -q . && break
            done
            echo ""
            ;;
        2)
            prompt path "Path to your age key file" ""
            path="${path/#\~/$HOME}"
            if [[ ! -f "$path" ]]; then
                error "File not found: $path"
                return 1
            fi
            raw="$(cat "$path")"
            ;;
        *)
            error "Invalid choice: $method"
            return 1
            ;;
    esac

    AGE_KEY_CONTENT="$(printf '%s\n' "$raw" | extract_age_keys)"
    if [[ -z "$AGE_KEY_CONTENT" ]]; then
        diagnose_age_input "$raw"
        return 1
    fi
    return 0
}

need_key=1
if sudo test -f "$AGE_KEY_FILE" 2>/dev/null; then
    if sudo cat "$AGE_KEY_FILE" | extract_age_keys | grep -q .; then
        info "Age key already exists at $AGE_KEY_FILE"
        echo -en "${BOLD}Replace it with a different key? [y/N]: ${RESET}"
        read -r REPLACE_KEY
        [[ "$REPLACE_KEY" =~ ^[Yy]$ ]] || need_key=0
    else
        warn "$AGE_KEY_FILE exists but doesn't contain a valid age key — it will be replaced."
    fi
fi

if [[ "$need_key" -eq 1 ]]; then
    echo ""
    echo "The home-manager config uses SOPS to decrypt secrets (SSH keys, API keys, etc.)."
    echo "You need to provide your age private key before the config can be applied."

    AGE_KEY_CONTENT=""
    until read_age_key; do
        echo -en "${BOLD}Try again? [Y/n]: ${RESET}"
        read -r RETRY
        [[ "$RETRY" =~ ^[Nn]$ ]] && die "Aborted — no valid age key provided."
    done

    sudo mkdir -p "$AGE_KEY_DIR"
    printf '%s\n' "$AGE_KEY_CONTENT" | sudo tee "$AGE_KEY_FILE" > /dev/null
    sudo chmod 600 "$AGE_KEY_FILE"
    info "Age key written to $AGE_KEY_FILE"
fi

# The sops-nix home-manager service runs as $CURRENT_USER (not root), so it must
# be able to read the key. Fix this every run — it also repairs a key that was
# saved as root-only (e.g. edited with sudo vim).
sudo chown "$CURRENT_USER":"$(id -gn)" "$AGE_KEY_FILE"
sudo chmod 600 "$AGE_KEY_FILE"
info "Age key is owned by $CURRENT_USER (mode 600)"


# ── 8. Clone dotfiles repo ────────────────────────────────────────────────────
section "debian-nix repo"

if [[ -f "$REPO_PATH/flake.nix" && -f "$REPO_PATH/home-manager/home.nix" ]]; then
    info "Using the repo at $REPO_PATH — skipping clone"
else
    echo -en "${BOLD}Do you need the repo cloned to $REPO_PATH? [Y/n]: ${RESET}"
    read -r NEED_CLONE
    if [[ "$NEED_CLONE" =~ ^[Nn]$ ]]; then
        prompt REPO_PATH "Path to your existing debian-nix repo" "$REPO_PATH"
        REPO_PATH="${REPO_PATH/#\~/$HOME}"
        [[ -f "$REPO_PATH/flake.nix" ]] || die "No debian-nix checkout found at $REPO_PATH.
  Re-run and answer 'y' to clone it, or give the correct path."
        info "Using existing repo at $REPO_PATH"
    else
        mkdir -p "$(dirname "$REPO_PATH")"
        info "Cloning $REPO_URL ..."
        git clone "$REPO_URL" "$REPO_PATH"
        info "Cloned to $REPO_PATH"
    fi
fi
mkdir -p "$(dirname "$DOTFILES_STATE")"
printf '%s\n' "$REPO_PATH" > "$DOTFILES_STATE"
info "nsr / nfu / update will use $REPO_PATH"

# targets.genericLinux.gpu.nvidia in home.nix must match the apt driver, or
# Nix-built GUI apps get no GL.
APT_NV="$(dpkg-query -W -f='${Version}' nvidia-driver 2>/dev/null | sed -E 's/-[^-]*$//' || true)"
HM_NV="$(grep -oE 'version = "[0-9.]+"' "$REPO_PATH/home-manager/home.nix" | cut -d'"' -f2 || true)"
if [[ -n "$APT_NV" && -n "$HM_NV" && "$APT_NV" != "$HM_NV" ]]; then
    warn "apt installed NVIDIA $APT_NV but home-manager/home.nix expects $HM_NV."
    warn "Update gpu.nvidia.version and its sha256 in home.nix before relying on Nix GUI apps."
fi

# ── 9. Apply home-manager config ──────────────────────────────────────────────
section "Applying home-manager config"

echo ""
# Existing dotfiles (e.g. ~/.config/mimeapps.list on a desktop install) would make
# home-manager refuse with "would be clobbered". -b moves them aside instead; the
# timestamp keeps a re-run from failing because an earlier backup already exists.
BACKUP_EXT="hm-backup-$(date +%Y%m%d-%H%M%S)"

info "Running: nix run home-manager/release-25.11 -- switch -b ${BACKUP_EXT} --flake ${REPO_PATH}#railgun"
echo ""
warn "This step downloads several GB of packages on first run. Be patient."
echo ""

if ! nix run home-manager/release-25.11 -- switch -b "$BACKUP_EXT" --flake "${REPO_PATH}#railgun"; then
    echo ""
    error "home-manager switch failed. Read the error above — common causes:"
    echo "  • 'experimental Nix feature ... is disabled'"
    echo "    → Check ~/.config/nix/nix.conf contains: experimental-features = nix-command flakes"
    echo "  • sops / age errors (failed to decrypt, no identity matched, permission denied)"
    echo "    → The key at $AGE_KEY_FILE is for a different recipient or unreadable."
    echo "      Re-run and answer 'y' to \"Replace it with a different key?\""
    echo "  • 'Existing file ... would be clobbered'"
    echo "    → Move or delete the named file, then re-run (normally handled by -b backup)"
    echo "  • Network issue mid-download"
    echo "    → Re-run this script; it's idempotent"
    echo "  • Nix store permission issue"
    echo "    → Make sure the nix-daemon is running: sudo systemctl status nix-daemon"
    exit 1
fi

info "home-manager config applied successfully"
if compgen -G "$HOME"/.*."$BACKUP_EXT" >/dev/null || compgen -G "$HOME"/.config/*."$BACKUP_EXT" >/dev/null; then
    warn "Existing files were backed up with the .${BACKUP_EXT} suffix (e.g. ~/.config/mimeapps.list.${BACKUP_EXT})."
    warn "Copy anything you still want out of them; they are safe to delete otherwise."
fi

# ── 10. Nix GPU drivers ───────────────────────────────────────────────────────
section "Nix GPU driver link"

# targets.genericLinux.gpu installs a root service that links the driver to
# /run/opengl-driver for Nix-built GL/Vulkan apps. It has to be (re)run with
# sudo after the first switch and after every driver version bump.
GPU_SETUP="$HOME/.nix-profile/bin/non-nixos-gpu-setup"
if [[ -x "$GPU_SETUP" ]]; then
    sudo "$(readlink -f "$GPU_SETUP")"
    info "Nix GPU drivers linked (non-nixos-gpu.service)"
else
    warn "$GPU_SETUP not found — run the sudo command home-manager printed above."
fi

# ── 11. Set zsh as default shell ──────────────────────────────────────────────
section "Setting zsh as default shell"

ZSH_PATH="$HOME/.nix-profile/bin/zsh"

if [[ "$(getent passwd "$CURRENT_USER" | cut -d: -f7)" == "$ZSH_PATH" ]]; then
    info "zsh is already the default shell"
else
    if [[ ! -f "$ZSH_PATH" ]]; then
        warn "zsh not found at $ZSH_PATH — home-manager may not have applied yet."
        warn "Skipping shell change; run 'chsh -s $ZSH_PATH' manually after re-login."
    else
        grep -qxF "$ZSH_PATH" /etc/shells || echo "$ZSH_PATH" | sudo tee -a /etc/shells > /dev/null
        chsh -s "$ZSH_PATH"
        info "Default shell set to $ZSH_PATH"
    fi
fi

# ── 12. Doom Emacs ────────────────────────────────────────────────────────────
section "Doom Emacs"

# Nix installs emacs; Doom and its config are plain git clones so Doom manages
# its own packages.
if [[ -d "$HOME/.config/emacs/.git" ]]; then
    info "Doom already cloned at ~/.config/emacs"
elif ask "Install Doom Emacs with the railgun210/doom-emacs config?"; then
    git clone --depth 1 https://github.com/doomemacs/doomemacs "$HOME/.config/emacs"
    [[ -d "$HOME/.config/doom" ]] \
        || git clone https://github.com/railgun210/doom-emacs "$HOME/.config/doom"
    PATH="$HOME/.nix-profile/bin:$PATH" "$HOME/.config/emacs/bin/doom" sync
    info "Doom installed — start it with Ctrl+Alt+Z (emacsclient) or 'emacs'"
fi

# ── 13. Flatpak apps ──────────────────────────────────────────────────────────
section "Flatpak apps"

if ask "Install the Flatpak apps (Smile, GDM Settings, P3X OneNote)?"; then
    sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    # it.mijorus.smile: emoji picker (Super+Shift+. in GNOME and i3)
    # io.github.realmazharhussain.GdmSettings: login screen settings
    sudo flatpak install -y --noninteractive flathub it.mijorus.smile io.github.realmazharhussain.GdmSettings

    # P3X OneNote is not on Flathub; it ships a .flatpak bundle on GitHub.
    if flatpak info com.patrikx3.onenote &>/dev/null; then
        info "P3X OneNote already installed"
    else
        ONENOTE_URL="$(github_asset patrikx3/onenote 'x86_64\.flatpak$' || true)"
        if [[ -n "$ONENOTE_URL" ]]; then
            ONENOTE_TMP="$(mktemp --suffix=.flatpak)"
            curl -fL -o "$ONENOTE_TMP" "$ONENOTE_URL"
            sudo flatpak install -y --noninteractive --bundle "$ONENOTE_TMP"
            rm -f "$ONENOTE_TMP"
            info "P3X OneNote installed"
        else
            warn "Could not find the P3X OneNote bundle — get it from github.com/patrikx3/onenote/releases"
        fi
    fi
fi

# ── 14. Anki ──────────────────────────────────────────────────────────────────
section "Anki"

# Anki's own Linux build (installs to /usr/local; Super+Shift+A launches it).
if command -v anki &>/dev/null; then
    info "Anki already installed ($(readlink -f "$(command -v anki)"))"
elif ask "Install Anki from its official release?"; then
    # Qt runtime libraries the bundle expects from the system, plus lame for
    # recording audio (mpv, for playback, comes from Nix).
    apt_install \
        libdbus-1-3 libfontconfig1 libfreetype6 libgl1 libnss3 libxcb-icccm4 \
        libxcb-image0 libxcb-keysyms1 libxcb-randr0 libxcb-render-util0 \
        libxcb-shape0 libxcb-xinerama0 libxcb-xkb1 libxcb-cursor0 libxcomposite1 \
        libxcursor1 libxi6 libxkbcommon0 libxkbcommon-x11-0 libxrandr2 \
        libxrender1 libxtst6 libglib2.0-0t64 lame
    ANKI_URL="$(github_asset ankitects/anki 'linux-x86_64\.tar(\.zst)?$' || true)"
    if [[ -n "$ANKI_URL" ]]; then
        ANKI_TMP="$(mktemp -d)"
        curl -fL -o "$ANKI_TMP/${ANKI_URL##*/}" "$ANKI_URL"
        tar -xf "$ANKI_TMP/${ANKI_URL##*/}" -C "$ANKI_TMP" # detects .zst itself
        (cd "$ANKI_TMP"/anki-*/ && sudo ./install.sh)
        rm -rf "$ANKI_TMP"
        info "Anki installed"
    else
        warn "Could not find the Anki download — get it from apps.ankiweb.net"
    fi
fi

# ── 15. PIA VPN ───────────────────────────────────────────────────────────────
section "PIA VPN"

if [[ -x /opt/piavpn/bin/piactl ]]; then
    info "PIA already installed ($(/opt/piavpn/bin/piactl --version 2>/dev/null || echo unknown version))"
elif ask "Install the PIA VPN client ($PIA_VERSION)?"; then
    PIA_RUN="$(mktemp --suffix=.run)"
    curl -fL -o "$PIA_RUN" "https://installers.privateinternetaccess.com/download/pia-linux-${PIA_VERSION}.run"
    chmod +x "$PIA_RUN"
    # The installer must run as the desktop user; it asks for sudo itself.
    "$PIA_RUN"
    rm -f "$PIA_RUN"
    info "PIA installed"
fi

# ── 16. Done ──────────────────────────────────────────────────────────────────
section "Bootstrap complete"

echo ""
echo -e "${GREEN}${BOLD}Everything is set up. Reboot (NVIDIA modesetting, GDM, new shell).${RESET}"
echo ""
echo -e "${BOLD}Left to do by hand:${RESET}"
echo "  □  At the GDM login screen, pick GNOME Classic (or i3) from the gear menu"
echo "  □  After the reboot, check NVIDIA modesetting: sudo cat /sys/module/nvidia_drm/parameters/modeset  (Y)"
echo "  □  Log in to PIA, Anki sync, Maestral and Thunderbird"
echo ""
echo -e "${BOLD}Rebuild after changes with:${RESET}"
echo "  nsr      (home-manager switch --flake ${REPO_PATH}#railgun, from any directory)"
echo ""
echo -e "${BOLD}Update flake inputs and rebuild with:${RESET}"
echo "  update   (zsh alias)"
echo ""
