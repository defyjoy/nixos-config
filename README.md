# nixos-config

My NixOS machine as a flake: GNOME desktop, zsh + oh-my-zsh + starship + atuin, git/ssh/gpg
identities, and the CLI/GUI tools from my Mac, ported from my macOS dotfiles.

`install.sh` wipes a disk, partitions it with [disko](https://github.com/nix-community/disko),
installs the system and sets the password. It asks two questions at the start (confirm the
disk, choose a password) and runs unattended after that.

| File | What it is |
|------|------------|
| `flake.nix` / `flake.lock` | Inputs pinned to NixOS 26.05, home-manager 26.05, disko |
| `configuration.nix` | System: boot, GNOME, user, sshd, docker, ollama, YubiKey, fonts |
| `home.nix` | User environment (home-manager): packages, zsh, git, ssh, gpg, dotfiles |
| `disko.nix` | Disk layout: GPT, 1 GB EFI `/boot`, ext4 `/` (swap is zram) |
| `hardware-configuration.nix` | Placeholder; `install.sh` regenerates it on the target |
| `files/` | Dotfiles copied verbatim from the Mac (starship, tmux, ghostty, zed, `git-use`) |
| `install.sh` | The installer |

No secrets live in this repo. Private keys, kubeconfigs and private SSH hosts are copied over
by hand in [step 5](#5-bring-over-secrets).

---

## Runbook

### 0. Before you start

You need:
- A target machine or VM that boots in **UEFI** mode (x86_64 or aarch64). systemd-boot doesn't
  support legacy BIOS.
- A disk you're happy to **erase completely**.
- Internet on the target. Wired is easiest.
- The YubiKey (`defyjoy-yubikey`). After install it's the only way to SSH in, and it holds the
  GPG signing key.

### 1. Make the installer USB (or VM)

Download the **Minimal ISO** for NixOS 26.05 from <https://nixos.org/download/#nixos-iso>
(x86_64 or aarch64, matching the target).

**USB stick, written from the Mac:**

```sh
diskutil list                                   # find the stick, e.g. /dev/disk4
diskutil unmountDisk /dev/disk4
sudo dd if=~/Downloads/nixos-minimal-*.iso of=/dev/rdisk4 bs=4m status=progress
```

In the target's firmware, turn **Secure Boot off** and boot from the stick.

**Proxmox VM:** upload the ISO, then create the VM with:
- Machine **q35**, BIOS **OVMF (UEFI)**
- An EFI disk with **Pre-Enroll keys unchecked**
- SCSI controller **VirtIO SCSI** (the disk then appears as `/dev/sda`)
- At least 4 GB RAM and a 40 GB disk

### 2. Get online on the installer

Wired Ethernet connects by itself. For Wi-Fi:

```sh
sudo systemctl start wpa_supplicant
wpa_cli
> add_network
> set_network 0 ssid "MyWifi"
> set_network 0 psk "password"
> enable_network 0
> quit
```

Check with `ping -c1 nixos.org`.

### 3. Install

```sh
lsblk -d -o NAME,SIZE,MODEL           # pick the target disk, e.g. nvme0n1 or sda
nix-shell -p git --run 'git clone https://github.com/defyjoy/nixos-config'
cd nixos-config
sudo ./install.sh /dev/nvme0n1        # use your disk from lsblk
```

What happens:
1. **You answer two prompts:** retype the disk path to confirm the wipe, then set the password
   for `joydeep`.
2. The disk path is written into `disko.nix`, then the disk is wiped, partitioned, formatted and
   mounted at `/mnt`.
3. `hardware-configuration.nix` is generated for this machine.
4. The repo is copied to `/home/joydeep/nixos-config` and `nixos-install` builds the system.
   This takes 10–30 minutes, depending on your connection.
5. Your password is set. Root stays locked, so use `sudo`.

When it prints `Done`, remove the USB stick (or detach the ISO) and run `reboot`.

### 4. First boot

Log in to GNOME as `joydeep`. Home-manager links your dotfiles during boot, so the first
terminal already has zsh, starship and atuin.

Find the machine's IP for the next step: `ip -4 addr` (or look in GNOME Settings → Network).

Check that it worked:

```sh
systemctl status home-manager-joydeep   # should be "active (exited)"
docker run --rm hello-world
```

### 5. Bring over secrets

Run these **from the Mac** with the YubiKey plugged in. The new machine's sshd accepts only
that key:

```sh
NEW=joydeep@<new-machine-ip>
alias sshnew='ssh -i ~/.ssh/defyjoy'    # the YubiKey-backed key

# SSH keys (add whichever other keys you need to the list)
scp -i ~/.ssh/defyjoy -p ~/.ssh/{defyjoy,proxmox}{,.pub} $NEW:.ssh/
sshnew $NEW git-use defyjoy              # point github.com at the defyjoy key

# Private SSH hosts (home lab etc.) that stay out of git: put Host blocks in ~/.ssh/config.local
scp -i ~/.ssh/defyjoy ~/.ssh/config.local $NEW:.ssh/config.local   # or create it by hand there

# kubeconfigs
scp -i ~/.ssh/defyjoy -r ~/.kube $NEW:
```

Example `~/.ssh/config.local`:

```
Host PVE01
  HostName 192.168.0.x
  User root
  IdentityFile ~/.ssh/proxmox
```

**GPG signing key** (`0B60C9CA8BC08E22`): it lives on the YubiKey, so only the public half has
to move. Then point gpg at the card:

```sh
gpg --export --armor 0B60C9CA8BC08E22 | sshnew $NEW gpg --import
# then, on the new machine with the YubiKey plugged in:
gpg --card-status
echo test | gpg --clearsign >/dev/null && echo "signing works"
```

**Then on the new machine:** run `gh auth login`, and `gcloud auth login` / `aws configure` if
you need them.

### 6. Track the install in git

`install.sh` rewrote `disko.nix` and `hardware-configuration.nix` for this machine. Commit them
so later rebuilds match the hardware:

```sh
cd ~/nixos-config
git remote set-url origin git@github.com:defyjoy/nixos-config.git
git add -A && git commit -m "hardware: <machine name>" && git push
```

---

## Day-to-day

```sh
cd ~/nixos-config
# edit configuration.nix (system) or home.nix (packages, shell, dotfiles), then:
sudo nixos-rebuild switch --flake .#nixos

# update all inputs (nixpkgs, home-manager, disko):
nix flake update && sudo nixos-rebuild switch --flake .#nixos

git commit -am "..." && git push
```

**Rolling back:** every rebuild adds a boot menu entry, so pick an older one at boot. Or run
`sudo nixos-rebuild switch --rollback`. Garbage collection runs weekly and keeps 14 days.

**Installing on a second machine:** run steps 1–6 again. Each machine's
`hardware-configuration.nix` is different, so give each one its own branch or host directory.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `Not booted in UEFI mode` | Enable UEFI and disable CSM/legacy in firmware. On Proxmox, set BIOS to OVMF. |
| Boots to firmware or "no bootable device" | Secure Boot is on, or (Proxmox) the EFI disk had pre-enrolled keys. Turn it off or recreate the EFI disk. |
| `nixos-install` runs out of space or memory | It builds in the target's `/mnt`, so give the VM at least 4 GB RAM and a 40 GB disk. |
| `Permission denied (publickey)` from the Mac | Use `ssh -i ~/.ssh/defyjoy`, and touch the YubiKey when it blinks. |
| A dotfile didn't change after a rebuild | `systemctl status home-manager-joydeep`. Existing files get backed up as `*.hm-bak` the first time. |
| Can't save settings in Zed | `~/.config/zed/settings.json` is managed. Edit `files/zed-settings.json` and rebuild. |

## What came over from the Mac

| Mac | NixOS |
|-----|-------|
| zinit + oh-my-zsh snippets | home-manager `oh-my-zsh` with the same plugin list, minus `dnf` and `command-not-found` |
| fast-syntax-highlighting, autosuggestions | `zsh-syntax-highlighting`, `zsh-autosuggestions` |
| `~/.zshrc` aliases, eza zstyles, kubeconfig merge | `home.nix` → `programs.zsh` |
| starship, tmux, ghostty, zed configs | `files/`, linked into place |
| atuin (`enter_accept`), zoxide, autojump, fzf, bat | `programs.*` in `home.nix` |
| `~/.gitconfig` + `~/.gitconfig-defyjoy` includeIf signing | `programs.git` (`settings` + `includes`) |
| `~/.ssh/config` GitHub profiles | `programs.ssh.settings`; `git-use` works as before |
| `~/.ssh/config` private hosts | `~/.ssh/config.local` (not in git) |
| nvm (lazy-loaded) | `nodejs` from nixpkgs (`nix shell nixpkgs#nodejs_20` for another version) |
| tfenv | `terraform` from nixpkgs |
| OrbStack | Docker (`joydeep` is in the `docker` group) |
| brew CLI tools | `home.packages` |
| Ghostty, Zed, Chrome, Slack, Firefox, DBeaver, Calibre, Claude Code | `home.packages` / `programs.firefox` (Chrome and Slack only on x86_64) |

**Not ported (macOS-only or no Linux build):** iTerm2, Raycast, Rectangle Pro, Bartender,
BetterMouse, Arc, Dia, ForkLift, Shottr, Macs Fan Control, PureMac, Notion, WhatsApp, Crest,
nyaterm, aside, langflow, yacreader, pinentry-mac, whalebrew, and the brew taps ziggity, sofka,
mole and github-keygen.

**Notes**
- Files home-manager manages (`~/.ssh/config`, `~/.config/zed/settings.json`, etc.) are
  read-only symlinks into the Nix store. Change them here and rebuild.
- Zed installs the themes your settings use (Dayfox/Nordfox, Catppuccin icons) once you add those
  extensions in Zed.
- Ghostty ignores the `macos-*` keys on Linux, and GNOME doesn't do background blur.
- To change the hostname, timezone or desktop, edit `configuration.nix`. For KDE, replace the
  GNOME/GDM lines with `services.desktopManager.plasma6.enable` and
  `services.displayManager.sddm.enable`.
