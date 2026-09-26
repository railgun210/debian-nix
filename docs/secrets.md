# Secrets Management (sops)

## The problem

This config lives on GitHub. SSH keys and passwords can't go in a `.nix` file —
that would publish them, and anything Nix builds ends up world-readable in
`/nix/store`.

[sops](https://github.com/getsops/sops) solves this: secrets are stored
encrypted in `secrets/`, which is safe to commit, and only a machine with the
right key can decrypt them. [sops-nix](https://github.com/Mic92/sops-nix)'s
Home Manager module runs a user service at every `home-manager switch` (and at
login) that decrypts them to `~/.config/sops-nix/secrets/`, outside the store.

Encryption uses **age**: one key file, no keyring daemon. The private key lives
at **`/etc/sops/age/keys.txt`**, owned by `railgun` with mode 600 (the sops-nix
service runs as your user). `home-manager/utilities/secrets.nix` points both
sops-nix and the `sops` CLI (`SOPS_AGE_KEY_FILE`) at it, and `.sops.yaml` at
the repo root lists the public key new secrets are encrypted for.

---

## What's stored

| File | What's in it | Used by |
|------|-------------|---------|
| `secrets/secrets.yaml` | `retroachievements-username`, `retroachievements-password` | `utilities/retroarch.nix` |
| `secrets/github-ssh-key.age` | GitHub SSH private key | `utilities/ssh.nix` |
| `secrets/github-ssh-key.pub` | GitHub SSH public key | `utilities/ssh.nix` (for pasting into GitHub) |

### Leftovers from the NixOS config

These are not referenced by anything and can be removed:

- `secrets/pia.age` (PIA WireGuard config — the PIA client doesn't need it)
- `secrets/weather-api-key.age` (the i3 weather module uses wttr.in, no key)
- the `wifi`, `anki-username` and `anki-sync-key` entries in `secrets.yaml`

```bash
git rm secrets/pia.age secrets/weather-api-key.age
sops unset secrets/secrets.yaml '["wifi"]'
sops unset secrets/secrets.yaml '["anki-username"]'
sops unset secrets/secrets.yaml '["anki-sync-key"]'
```

---

## Fresh machine, existing key

`scripts/bootstrap.sh` asks for the key and installs it. By hand:

```bash
sudo mkdir -p /etc/sops/age
sudo cp your-age-key.txt /etc/sops/age/keys.txt
sudo chown "$USER": /etc/sops/age/keys.txt
sudo chmod 600 /etc/sops/age/keys.txt
```

Then `home-manager switch` decrypts everything.

---

## New key (lost the old one, or a new owner)

**1 — Generate a key**

```bash
sudo mkdir -p /etc/sops/age
nix shell nixpkgs#age -c age-keygen -o keys.txt
sudo mv keys.txt /etc/sops/age/keys.txt
sudo chown "$USER": /etc/sops/age/keys.txt && sudo chmod 600 /etc/sops/age/keys.txt
```

`age-keygen` prints the public key (`age1...`). Get it again any time with
`age-keygen -y /etc/sops/age/keys.txt`.

**2 — Put the public key in `.sops.yaml`**

Replace (or add next to) the `&railgun` key under `keys:`.

**3 — Re-encrypt**

If you still have the *old* key, re-encrypt each file for the new recipients:

```bash
sops updatekeys secrets/secrets.yaml
sops updatekeys secrets/github-ssh-key.age
sops updatekeys secrets/github-ssh-key.pub
```

If the old key is gone, the existing secrets can't be recovered — recreate
them (see below) with the new key.

**4 — Rebuild**

```bash
nsr
```

---

## Editing secrets

```bash
dotfiles # cd into the repo
sops secrets/secrets.yaml
```

sops decrypts the file into `$EDITOR` (emacsclient), and re-encrypts it when
you save and close. Run `nsr` afterwards.

### RetroAchievements

```yaml
retroachievements-username: "your_username"
retroachievements-password: "your_password"
```

An activation step writes them into `~/.config/retroarch/retroarch.cfg` (mode
600) at every switch. If the sops service hadn't decrypted them yet on the
very first switch, run `nsr` once more.

### SSH key

Encrypt a key as a binary secret (the `.sops.yaml` rule picks the recipients):

```bash
sops encrypt --input-type binary --output secrets/github-ssh-key.age ~/.ssh/github
sops encrypt --input-type binary --output secrets/github-ssh-key.pub ~/.ssh/github.pub
```

`ssh.nix` points the `github.com` host at the decrypted key, and the git config
in `home.nix` rewrites `https://github.com/` URLs to SSH so pushes use it.

### Adding a new secret

1. Add the value with `sops secrets/secrets.yaml` (or encrypt a new file as above).
2. Declare it in a module:

   ```nix
   sops.secrets.my-token.sopsFile = ../../secrets/secrets.yaml;
   ```

3. Read it at runtime from `config.sops.secrets.my-token.path`
   (`~/.config/sops-nix/secrets/my-token`). Never interpolate the value itself
   into a Nix string — that would copy it into the store.
