# Debian + Home Manager Setup

`scripts/bootstrap.sh` does everything below in order. This is the same
walkthrough by hand — useful when a step fails, or to see what the script
changes. Sections match the script's step numbers.

---

## 0. Install Debian

Boot the Debian 13 (Trixie) installer. Create the user **`railgun`** (the
config hardcodes the username and `/home/railgun`). In software selection
(tasksel) check **standard system utilities** only — GNOME is installed by
hand below so it stays minimal. (Picking a desktop there also works but pulls
in its full app set.)

After the install:

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install git
git clone https://github.com/railgun210/debian-nix ~/GitRepos/debian-nix
```

---

## 2. APT sources and architectures

Trixie's installer only enables `main non-free-firmware`, so `nvidia-driver`
and `steam-installer` have "no installation candidate" until `contrib` and
`non-free` are added. Steam and the NVIDIA 32-bit GL libraries also need i386:

```bash
sudo sed -i -E '/^deb/ s/ main non-free-firmware$/ main contrib non-free non-free-firmware/' /etc/apt/sources.list
sudo dpkg --add-architecture i386
sudo apt update
sudo apt install curl git xz-utils zstd ca-certificates
```

---

## 3. APT packages

### GNOME (Wayland, GDM)

A minimal GNOME Classic session, the extensions `desktops/gnome/default.nix`
enables, and the desktop basics a "standard utilities" install doesn't have:

```bash
sudo apt install \
  gdm3 gnome-session gnome-classic gnome-shell-extensions \
  gnome-shell-extension-appindicator gnome-shell-extension-desktop-icons-ng \
  gnome-shell-extension-user-theme gnome-tweaks \
  nautilus gnome-control-center gnome-terminal file-roller loupe papers \
  gnome-system-monitor xdg-desktop-portal-gnome \
  network-manager network-manager-gnome pipewire-audio bluez \
  flatpak gnome-software-plugin-flatpak
sudo systemctl enable gdm3
```

Choose **gdm3** if apt asks which display manager to use (or run
`sudo dpkg-reconfigure gdm3` later).

### Apps and tools

```bash
# BROWSER and the Office MIME defaults (utilities/default-apps.nix) point here
sudo apt install firefox-esr libreoffice-writer libreoffice-calc libreoffice-impress libreoffice-gnome

# CLI tools kept outside Nix
sudo apt install vim btop apt-file netselect-apt
sudo apt-file update

# GTK2 engine + themes from the old MATE setup
sudo apt install gtk2-engines-murrine murrine-themes shiki-colors
```

### i3 session (optional)

`home-manager/desktops/i3/` configures an i3 (X11) session next to GNOME.
Only the pieces that need root come from apt: the GDM session entry, the
PAM-backed screen locker, the compositor (which uses Debian's NVIDIA GL
directly), the polkit agent and the Bluetooth tray applet.

```bash
sudo apt install i3-wm i3lock xss-lock picom mate-polkit blueman
```

Everything else (dmenu, i3status, dunst, feh, autotiling, ...) comes from Nix.

### Steam (optional)

```bash
sudo apt install steam-installer
```

---

## 4. NVIDIA driver

```bash
sudo apt install linux-headers-amd64 nvidia-driver nvidia-driver-libs:i386 firmware-misc-nonfree
```

`nvidia-driver-libs:i386` provides the 32-bit GL libraries 32-bit Steam needs:
the driver's `glx-diversions` moves Mesa's 32-bit `libGL.so.1` aside, so
without it Steam dies with `steamui.so failed: libGL.so.1: wrong ELF class`.

### DRM modesetting (required for GNOME on Wayland)

Debian's NVIDIA packages leave `nvidia-drm` modesetting off, and GDM then
silently falls back to Xorg:

```bash
echo 'options nvidia-drm modeset=1 fbdev=1' | sudo tee /etc/modprobe.d/nvidia-drm-modeset.conf
```

### Suspend

Keep video memory across suspend so the Wayland session comes back intact:

```bash
echo 'options nvidia NVreg_PreserveVideoMemoryAllocations=1 NVreg_TemporaryFilePath=/var/tmp' \
  | sudo tee /etc/modprobe.d/nvidia-power-management.conf
sudo systemctl enable nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service
```

Then rebuild the initramfs and reboot:

```bash
sudo update-initramfs -u
sudo reboot
```

Afterwards `nvidia-smi` should list the GPU and this must print `Y`:

```bash
sudo cat /sys/module/nvidia_drm/parameters/modeset
```

### Keep home.nix in sync

`targets.genericLinux.gpu.nvidia` in `home-manager/home.nix` builds the same
driver's userspace for Nix-built GL/Vulkan apps (Ghostty, RetroArch, ...). Its
`version` must match `dpkg-query -W nvidia-driver` (without the `-N` Debian
suffix). After a driver update, change `version`, set `sha256` to
`lib.fakeHash`, run `nrt` to get the real hash from the error, then switch and
re-run step 10.

---

## 5–6. Install Nix and enable flakes

```bash
sh <(curl -L https://nixos.org/nix/install) --daemon
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

mkdir -p ~/.config/nix
echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf
```

---

## 7. The age key for secrets

sops-nix decrypts secrets during activation, so the age private key must be
in place before the first `home-manager switch`:

```bash
sudo mkdir -p /etc/sops/age
sudo cp your-age-key.txt /etc/sops/age/keys.txt
sudo chown "$USER": /etc/sops/age/keys.txt
sudo chmod 600 /etc/sops/age/keys.txt
```

The sops-nix service runs as your user, so the file must be yours. No key
yet? See [secrets.md](secrets.md).

---

## 9. Apply home-manager

```bash
nix run home-manager/release-25.11 -- switch -b hm-backup --flake ~/GitRepos/debian-nix#railgun
```

`-b hm-backup` moves files that would be overwritten (e.g. a desktop's
`~/.config/mimeapps.list`) aside instead of failing. After this,
`home-manager` is on your `PATH` and `nsr` does the same switch. The repo
doesn't have to be in `~/GitRepos`: run `nsr` once from inside the clone and
the commands remember where it is (see the README).

---

## 10. Nix GPU driver link

The switch prints a `sudo .../non-nixos-gpu-setup` command. It installs a
root service that links the driver built in step 4 to `/run/opengl-driver`,
where Nix GL apps look for it. Run it once, and again after every driver
version bump:

```bash
sudo "$(readlink -f ~/.nix-profile/bin/non-nixos-gpu-setup)"
```

---

## 11. zsh as the login shell

The Nix zsh isn't in `/etc/shells` by default:

```bash
echo "$HOME/.nix-profile/bin/zsh" | sudo tee -a /etc/shells
chsh -s "$HOME/.nix-profile/bin/zsh"
```

---

## 12. Doom Emacs

```bash
git clone --depth 1 https://github.com/doomemacs/doomemacs ~/.config/emacs
git clone https://github.com/railgun210/doom-emacs ~/.config/doom
~/.config/emacs/bin/doom sync
```

---

## 13. Flatpak apps

```bash
sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
sudo flatpak install flathub it.mijorus.smile io.github.realmazharhussain.GdmSettings
```

- **Smile** — emoji picker, `Super+Shift+.` in both sessions
- **GDM Settings** — login screen wallpaper and theme (GDM isn't themed by Stylix)

**P3X OneNote** isn't on Flathub. Download the `x86_64.flatpak` bundle from
[its releases](https://github.com/patrikx3/onenote/releases) and install it
with `sudo flatpak install --bundle P3X-OneNote-*-x86_64.flatpak`.

`home.nix` adds the Flatpak export directories to `XDG_DATA_DIRS`, so the
apps appear in GNOME's app grid and the i3 launcher.

---

## 14. Anki

Anki's official Linux build, which updates itself outside apt. It needs these
Qt runtime libraries, plus `lame` for recording audio (mpv comes from Nix):

```bash
sudo apt install \
  libdbus-1-3 libfontconfig1 libfreetype6 libgl1 libnss3 libxcb-icccm4 \
  libxcb-image0 libxcb-keysyms1 libxcb-randr0 libxcb-render-util0 \
  libxcb-shape0 libxcb-xinerama0 libxcb-xkb1 libxcb-cursor0 libxcomposite1 \
  libxcursor1 libxi6 libxkbcommon0 libxkbcommon-x11-0 libxrandr2 \
  libxrender1 libxtst6 libglib2.0-0t64 lame
```

Download `anki-<version>-linux-x86_64.tar.zst` from
[the releases](https://github.com/ankitects/anki/releases), extract it and run
`sudo ./install.sh` inside. It installs to `/usr/local/share/anki` with
`/usr/local/bin/anki` (`Super+Shift+A` in both sessions).

---

## 15. PIA VPN

Download and run the official installer as your normal user (it asks for
sudo itself). `bootstrap.sh` pins the version in `PIA_VERSION`:

```bash
curl -LO https://installers.privateinternetaccess.com/download/pia-linux-3.7.2-08420.run
sh pia-linux-3.7.2-08420.run
```

---

## After the reboot

- At the GDM login screen, click the gear and pick **GNOME Classic**
  (Wayland) or **i3**. The extensions, icons, keybindings, workspaces, monitor
  layout and font rendering are already configured by home-manager.
- GNOME's other settings (power, lock screen, ...) are set in GNOME Settings;
  anything declared in `desktops/gnome/default.nix` is re-applied at every
  switch.
- Log in to PIA, Anki sync, Maestral (Dropbox) and Thunderbird.

---

## Rebuilding after changes

```bash
nsr      # home-manager switch for this repo, wherever it's cloned
update   # nix flake update, then switch
cleanup  # garbage-collect old generations
```
