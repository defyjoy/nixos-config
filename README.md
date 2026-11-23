# nixos-config

My CachyOS desktop rebuilt on NixOS: the **Niri** compositor and **Noctalia** shell with every config
from [defyjoy/.dotfiles](https://github.com/defyjoy/.dotfiles). That covers fish + starship, Alacritty,
Material You colours taken from the wallpaper, Firefox/Zen, and the YubiKey for SSH and GPG. My Mac
CLI tools come along too, with zsh and git.

`install.sh` wipes a disk and partitions it with [disko](https://github.com/nix-community/disko) (btrfs).
It then installs the system and sets your password. It asks two questions up front (confirm the disk,
choose a password) and then runs unattended.

| File | What it is |
|------|------------|
| `flake.nix` / `flake.lock` | Pinned inputs: NixOS 26.05, home-manager, disko, Noctalia 5.6, Zen, `.dotfiles`, CachyOS fish config |
| `configuration.nix` | Base system: boot, user `defyjoy`, locale `en_IN`, DNS-over-TLS, sshd, YubiKey, snapper, docker |
| `desktop.nix` | Desktop system side: niri, Noctalia, cosmic-greeter, PipeWire, Solaar, Steam, fonts, cursors/icons |
| `nvidia.nix` | RTX 4070 Super (open driver, PowerMizer fix, container toolkit). Only used when `gpu.nix` imports it |
| `gpu.nix` | Empty by default; `install.sh` makes it import `nvidia.nix` if the machine has an NVIDIA GPU |
| `home.nix` | From the Mac: CLI packages, zsh + oh-my-zsh, git signing, gpg-agent, tmux, zed |
| `home-desktop.nix` | Desktop user side: puts the `.dotfiles` `home/` tree in place, plus Firefox chrome, gsettings, Zen and desktop apps |
| `disko.nix` | GPT, 1 GB EFI `/boot`, btrfs subvolumes `@ @home @home-snapshots @nix @log` (zstd), zram swap |
| `hardware-configuration.nix` | Placeholder; `install.sh` regenerates it on the target |
| `install.sh` | The installer |

## How the dotfiles are applied

The `.dotfiles` repo is a flake input, pinned in `flake.lock`. Its `home/` tree is **copied** into
`~`, not symlinked, because Noctalia and Solaar rewrite their own configs (colours, `settings.toml`,
Solaar state). CachyOS paths are swapped for NixOS ones on the way in:

| In `.dotfiles` | On NixOS |
|---|---|
| `/usr/share/cachyos-fish-config` | `/etc/cachyos-fish-config` (CachyOS's repo, pinned) |
| `/usr/lib/node_modules/alacritty-themes/themes` | `/etc/alacritty-themes` |
| `/usr/share/icons` (cursor-theme) | `/run/current-system/sw/share/icons` |
| `zen-browser` / `zen.desktop` | `zen-beta` / `zen-beta.desktop` |
| `/usr/bin/noctalia` (Pywalfox host) | Noctalia from the flake (home-manager writes the manifest) |
| `.gnupg/gpg-agent.conf` | home-manager `services.gpg-agent`, with the same settings |
| `.zshrc` (CachyOS zsh) | home-manager zsh from `home.nix` |
| `/etc` files, gsettings, packages | Nix options in `configuration.nix`, `desktop.nix`, `nvidia.nix`, `home-desktop.nix` |

- **Every rebuild** copies over any file you don't have yet. It never overwrites files that already exist.
- **`dotfiles-apply`** forcibly copies the pinned `.dotfiles` over your live files. Each file it replaces
  is backed up to `~/.dotfiles-backup/<date>/`.
- **To pull new `.dotfiles` commits:**
  `nix flake update dotfiles && sudo nixos-rebuild switch --flake .#nixos && dotfiles-apply`

No secrets live in this repo or in `.dotfiles`. Keys, kubeconfigs and wallpapers are brought over by hand.

---

## Runbook

### 0. Before you start

You need:
- A **UEFI** machine or VM, x86_64 (Steam and Chrome are x86_64-only; aarch64 works without them).
- A disk you're happy to **erase completely**.
- Internet on the target. Wired is easiest.
- The YubiKey: it's the only way to SSH in, and it holds your GitHub SSH key and GPG signing key.
- Your wallpapers (~80 MB, `~/Pictures/Wallpapers` on the CachyOS box). Noctalia's colours come from them.

NVIDIA is optional: `install.sh` turns on `nvidia.nix` only if it finds an NVIDIA card. Apple Silicon,
AMD/Intel machines and VMs get no NVIDIA config.

**Apple Silicon (e.g. M1 Ultra Mac Studio):** the standard NixOS ISO can't boot a Mac on bare metal.
Install into a VM on macOS instead (UTM or VMware Fusion, aarch64 ISO, UEFI), and the steps below
work unchanged. A bare-metal install needs Asahi Linux via
[nixos-apple-silicon](https://github.com/nix-community/nixos-apple-silicon), which this repo doesn't set up.

### 1. Make the installer USB (or VM)

Download the **Minimal ISO** for NixOS 26.05 from <https://nixos.org/download/#nixos-iso>.

**USB stick, written from the Mac:**

```sh
diskutil list                                   # find the stick, e.g. /dev/disk4
diskutil unmountDisk /dev/disk4
sudo dd if=~/Downloads/nixos-minimal-*.iso of=/dev/rdisk4 bs=4m status=progress
```

In the target's firmware, turn **Secure Boot off** and boot from the stick.

**Proxmox VM:** machine **q35**, BIOS **OVMF (UEFI)**, EFI disk with **Pre-Enroll keys unchecked**,
**VirtIO SCSI** (disk shows up as `/dev/sda`), at least 8 GB RAM and a 60 GB disk.

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
lsblk -d -o NAME,SIZE,MODEL           # pick the target disk, e.g. nvme0n1
nix-shell -p git --run 'git clone https://github.com/defyjoy/nixos-config'
cd nixos-config
sudo ./install.sh /dev/nvme0n1        # use your disk from lsblk
```

What happens:
1. **You answer two prompts:** retype the disk path to confirm the wipe, then set the password for `defyjoy`.
2. The disk is wiped and set up as btrfs with subvolumes, then mounted at `/mnt`.
3. `hardware-configuration.nix` is generated for this machine.
4. The repo is copied to `/home/defyjoy/nixos-config` and `nixos-install` builds the system. Expect
   **20–40 minutes**: Noctalia is compiled from source because the binary cache doesn't have it.
5. Your password is set. Root stays locked, so use `sudo`.

When it prints `Done`, remove the USB stick and run `reboot`.

### 4. First login

At **cosmic-greeter**, pick the **niri** session and log in as `defyjoy`. Noctalia (bar and dock) and
Solaar start on their own. Key bindings are unchanged from CachyOS:

- `Mod+Return`: Alacritty
- `Mod+D`: launcher
- `Mod+S`: control centre
- `Mod+B` / `Ctrl+B`: Firefox / Zen
- `Mod+Shift+Escape`: all hotkeys

Then:

1. **Wallpapers.** Copy them into `~/Pictures/Wallpapers` (e.g. `scp -r` from the old box). Noctalia's
   `settings.toml` points at `uwshot-1341.jpg` in there. Until that file exists you'll have no
   wallpaper and default colours.
2. **Display.** Run `niri msg outputs`. `~/.config/niri/cfg/display.kdl` expects the G9 on `DP-1`
   (5120x1440@120). Change the name if it differs. niri reloads the file live.
3. **Firefox.** Install the **Pywalfox** extension. Its colours then follow Noctalia; no pip package is needed.
4. **Zen.** Zen mods (`browser/zen/chrome/zen-themes.css` in `.dotfiles`) aren't copied in. Re-add them in Zen.

### 5. YubiKey: SSH and GPG

These steps follow the `.dotfiles` README.

```sh
# GitHub SSH = FIDO2 resident key on the YubiKey (PIN + touch). Writes ~/.ssh/id_ed25519_sk_rk_defyjoy
cd ~/.ssh && ssh-keygen -K
ssh -T git@github.com                        # "Hi defyjoy!"

# GPG = OpenPGP card. Import the public key (it isn't on a keyserver), then trust it.
# On the Mac:  gpg --export --armor 0B60C9CA8BC08E22 > pubkey.asc   then copy it over
gpg --import pubkey.asc
gpg --card-status
gpg --edit-key 0B60C9CA8BC08E22 trust        # choose 5 (ultimate), then quit
ssh-add -L                                   # the card's auth key, via gpg-agent
```

Other keys (e.g. `~/.ssh/proxmox`) and `~/.kube` are copied by hand. `~/.ssh/config` is the editable
copy from `.dotfiles`, so add private hosts there. Then run `gh auth login`, and `gcloud auth login` /
`aws configure` if you need them.

### 6. Commit this machine's hardware

`install.sh` rewrote `disko.nix`, `hardware-configuration.nix` and (with NVIDIA) `gpu.nix` for this machine. Commit them so
rebuilds match the hardware:

```sh
cd ~/nixos-config
git remote set-url origin git@github.com:defyjoy/nixos-config.git
git add -A && git commit -m "hardware: <machine name>" && git push
```

### 7. Verify

```sh
niri validate                                        # config parses
niri msg outputs                                     # G9 at 5120x1440@119.999 on DP-1
noctalia msg theme-mode-get                          # light 08:00-17:00, dark otherwise
resolvectl status | grep -E 'DNSOverTLS|Current DNS' # +DNSOverTLS, 1.1.1.1#cloudflare-dns.com
snapper -c home list | head                          # hourly /home snapshots, no root needed
nvidia-smi --query-gpu=pstate --format=csv,noheader  # P0/P2 under load (NVIDIA only)
ssh -T git@github.com && gpg --card-status
```

Then look for: translucent Alacritty/Firefox with blur, gradient focus ring, Noctalia bar and dock,
and colours that match the wallpaper.

---

## Day-to-day

```sh
cd ~/nixos-config
# system: configuration.nix / desktop.nix    user: home.nix / home-desktop.nix
sudo nixos-rebuild switch --flake .#nixos

nix flake update && sudo nixos-rebuild switch --flake .#nixos   # update everything
git commit -am "..." && git push
```

**Rolling back:** every rebuild adds a boot menu entry, so pick an older one at boot, or run
`sudo nixos-rebuild switch --rollback`. `/home` also has hourly snapper snapshots (5 hourly, 7 daily).
Garbage collection runs weekly and keeps 14 days.

**Changing desktop configs:** edit the live file (e.g. `~/.config/niri/cfg/keybinds.kdl`) and it applies
at once. To keep the change, copy it into the `.dotfiles` repo and push. A plain rebuild never
overwrites your edits.

## Gotchas (carried over from `.dotfiles`)

- Keep niri **2.5px corners and gaps 8**. Alacritty stays dark-only, and its `import = [...]` stays multi-line.
- Edit colours in `~/.config/noctalia/templates/`, never in the generated files (`niri/cfg/colors.kdl`,
  `alacritty/themes/noctalia-*.toml`, `gtk-*/noctalia*.css`, `qt*ct/colors`, the btop theme, the starship palette).
- Quit Solaar before editing its config, or it overwrites the file on exit.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `Not booted in UEFI mode` | Enable UEFI and disable CSM/legacy. On Proxmox, set BIOS to OVMF. |
| Boots to firmware / no bootable device | Secure Boot is on, or the Proxmox EFI disk has pre-enrolled keys. |
| NVIDIA enabled or missing on the wrong machine | Edit `gpu.nix`: `{ }` for none, `{ imports = [ ./nvidia.nix ]; }` for NVIDIA. Then rebuild. |
| No wallpaper, default colours | `~/Pictures/Wallpapers/uwshot-1341.jpg` is missing (step 4.1). |
| A config didn't change after `nix flake update dotfiles` | Rebuilds only add missing files. Run `dotfiles-apply`. |
| `ssh -T git@github.com` fails | Run `ssh-keygen -K` in `~/.ssh` (step 5), then touch the key when it blinks. |
| A home-manager file conflicts | `systemctl status home-manager-defyjoy`. Existing files get backed up as `*.hm-bak` once. |

## What's different from CachyOS

- **Kept:**
  - niri 26.04 (validated against your config) and Noctalia 5.6.
  - cosmic-greeter, fish with the CachyOS fish config, Alacritty, and Firefox with userChrome/user.js.
  - Zen, Solaar, Steam, Docker + NVIDIA container toolkit.
  - Snapper on `/home`, DNS-over-TLS, the `en_IN` locale, and PipeWire.
  - Inter/Noto/JetBrains/Meslo fonts, the Papirus icons and the Bibata cursor.
- **Replaced:**
  - The CachyOS kernel with the NixOS default kernel.
  - Limine with systemd-boot. NixOS generations stand in for limine-snapper-sync root snapshots.
  - ufw with the NixOS firewall, and the nmcli DNS step with resolved `Domains=~.`.
- **Dropped:** CachyOS tools (hello, kernel manager, mirror tools, chwd), the COSMIC desktop leftovers,
  `devin-desktop`, `llmfit`, and the extra cursor themes (BreezeX, Oreo).
- **From the Mac** (`home.nix`): CLI tools, zsh + oh-my-zsh (fish is the login shell, run `zsh` for
  this), signed git commits, tmux and Zed. On x86_64 only (skipped on the M1 Ultra / aarch64): Chrome, Slack,
  qemu, lima, google-cloud-sdk, DBeaver and Calibre. Ghostty is dropped; Alacritty is the terminal. `git-use`
  is gone; the YubiKey resident key replaces it.
