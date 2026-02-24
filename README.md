Perfect — then the rule is:

* **Run `chezmoi add` as user `jroychowdhury`** (so it writes into `/home/jroychowdhury/.local/share/chezmoi`)
* Use **sudo only for apply** (to write into `/etc`), and (optionally) for read access if `/etc/nixos` permissions block you.

## Getting started

On a new machine, install git and chezmoi via Nix, then init and apply this repo:

```bash
sudo nix-shell -p git chezmoi
chezmoi init --apply opsquark
```

Do this:

## 1) Confirm your user chezmoi repo path

```bash
chezmoi source-path
```

You should see:
`/home/jroychowdhury/.local/share/chezmoi`

## 2) Add `/etc/nixos` into *your* repo (not root’s)

### Try (usually works):

```bash
chezmoi add --destination / -r /etc/nixos
```

### If that fails due to permissions, use this (reads as root, writes repo as you):

```bash
sudo -u jroychowdhury -H chezmoi add --destination / -r /etc/nixos
```

## 3) Verify files were added into your repo

```bash
chezmoi status --destination /
chezmoi cd
git status
```

## 4) Apply to `/etc/nixos` (needs root)

```bash
sudo chezmoi apply --destination /
```

---

## Optional: make “apply to /” easy without accidentally using root’s repo

Always apply using your user’s source directory but with root privileges:

```bash
sudo -u root --preserve-env=HOME,USER,PATH chezmoi apply --destination /
```

But simplest is:

```bash
sudo chezmoi apply --destination /
```

**as long as** you ensure `sudo` is not switching HOME to `/root`. Many distros do. To force it to use your user source dir, use:

```bash
sudo HOME=/home/jroychowdhury chezmoi apply --destination /
```

(That guarantees it uses `/home/jroychowdhury/.local/share/chezmoi`.)

---

## The most reliable “always use my repo” commands

**Add:**

```bash
chezmoi add --destination / -r /etc/nixos
```

**Apply (force your repo even under sudo):**

```bash
sudo HOME=/home/jroychowdhury chezmoi apply --destination /
```

---

### Quick diagnostic if it still “adds nothing”

Run:

```bash
chezmoi status --destination /
chezmoi managed --destination / | head
```

If you paste the output of:

```bash
chezmoi source-path
sudo env | grep -E '^(HOME|USER)='
```

I’ll give you the exact one-liner that works on your sudo environment.
---


Here’s the clean “new machine bootstrap” flow when you keep the *real* NixOS config in your home (managed by **chezmoi**) and `/etc/nixos/configuration.nix` is just a tiny stub that imports it.

## Goal layout

* Real config tracked by chezmoi:
  `~/.config/nixos/*`  (or `~/dotfiles/nixos/*`)
* `/etc/nixos/configuration.nix` imports from that path

---

## On a brand-new NixOS install

### 1) Install Git + chezmoi (temporarily) and fetch your repo

You can do this right after first boot.

```bash
sudo nix-shell -p git chezmoi
chezmoi init --apply opsquark
```

This will populate your dotfiles into your home, including `~/.config/nixos/...` (because your repo contains it).

> If your repo is private and you use SSH, you may need to set up SSH keys first (or use HTTPS + token).

---

### 2) Put a stub `/etc/nixos/configuration.nix` that imports your repo config

Now switch to root for writing `/etc/nixos`:

```bash
sudo -i
```

Replace `/etc/nixos/configuration.nix` with:

```nix
{ config, pkgs, ... }:
{
  imports = [
    /home/jroychowdhury/.config/nixos/host.nix
  ];
}
```

Exit root:

```bash
exit
```

---

### 3) Ensure your home config imports the machine hardware config

On a brand new install, the hardware file is generated at:
`/etc/nixos/hardware-configuration.nix`

You have two good approaches:

#### Approach A (simple): copy the generated hardware file into your repo path

```bash
mkdir -p ~/.config/nixos
sudo cp /etc/nixos/hardware-configuration.nix ~/.config/nixos/hardware-configuration.nix
```

Then make sure `~/.config/nixos/host.nix` includes it, e.g.:

```nix
{ config, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./configuration.nix
  ];
}
```

Now track it with chezmoi:

```bash
chezmoi add ~/.config/nixos/hardware-configuration.nix
chezmoi cd
git add -A
git commit -m "Add hardware config for new host"
git push
```

#### Approach B (better for multi-host): keep hardware config per-host

If you manage multiple machines, store:
`~/.config/nixos/hosts/<hostname>/hardware-configuration.nix`
and have `host.nix` pick the right one (you can template this later with chezmoi).

---

### 4) Rebuild using your imported config

```bash
sudo nixos-rebuild switch
```

If your config includes Home Manager as a NixOS module, that will also apply your HM config in the same rebuild. If HM is standalone, run:

```bash
home-manager switch
```

---

## One-command “bootstrap” (copy/paste)

Assuming:

* your repo contains `~/.config/nixos/host.nix` + `configuration.nix`
* you want to copy the new machine’s hardware file into `~/.config/nixos/`

```bash
sudo nix-shell -p git chezmoi --run '
chezmoi init --apply opsquark
sudo tee /etc/nixos/configuration.nix >/dev/null <<EOF
{ config, pkgs, ... }:
{
  imports = [
    /home/jroychowdhury/.config/nixos/host.nix
  ];
}
EOF
sudo cp /etc/nixos/hardware-configuration.nix /home/jroychowdhowdhury/.config/nixos/hardware-configuration.nix
sudo nixos-rebuild switch
'
```

(Replace repo URL; also note the username path — keep it exactly `jroychowdhury`.)

---

## Practical notes

* The only “manual” bit on a fresh machine is **getting the generated `hardware-configuration.nix`** into wherever your repo expects it.
* If your config path hardcodes `/home/jroychowdhury/...`, it will work as long as the username matches. If you want it portable across machines/users, we can switch to a flake-based host layout or use templating.

If you paste your current repo’s `~/.config/nixos/` tree (file names only), I’ll give you the exact minimal stub + import wiring that matches your structure.

## Commands 
```
# 0) become your user (first boot) and get network working

# 1) get git + chezmoi for this session
sudo nix-shell -p git chezmoi

# 2) init chezmoi from your repo (this will create/populate ~/.local/share/chezmoi)
chezmoi init --apply opsquark

# 3) sanity-check chezmoi is using your home source dir
chezmoi source-path

# 4) ensure your nixos config directory exists (in case repo expects it)
mkdir -p ~/.config/nixos

# 5) create /etc/nixos/configuration.nix stub that imports your home-managed config
# (If your repo uses ~/.config/nixos/host.nix keep this as-is; otherwise change host.nix -> configuration.nix)
sudo tee /etc/nixos/configuration.nix >/dev/null <<'EOF'
{ config, pkgs, ... }:
{
  imports = [
    /home/jroychowdhury/.config/nixos/host.nix
  ];
}
EOF

# 6) copy this machine's generated hardware config into your home-managed nixos config
sudo cp /etc/nixos/hardware-configuration.nix /home/jroychowdhury/.config/nixos/hardware-configuration.nix
sudo chown jroychowdhury:users /home/jroychowdhury/.config/nixos/hardware-configuration.nix

# 7) apply the system configuration
sudo nixos-rebuild switch

# 8) (optional) if you use standalone home-manager (not NixOS module), apply it too:
# nix-shell -p home-manager --run "home-manager switch"
```
