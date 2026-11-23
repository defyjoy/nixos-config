#!/usr/bin/env bash
# Run from the NixOS installer ISO, inside this repo:  sudo ./install.sh /dev/<disk>
# Wipes <disk>, partitions it with disko.nix, installs this flake, sets your password.
set -euo pipefail

DISK="${1:-}"
USER_NAME=defyjoy
REPO="$(cd "$(dirname "$0")" && pwd)"
TARGET="/mnt/home/$USER_NAME/nixos-config"

[[ $EUID -eq 0 ]] || { echo "Run as root: sudo $0 /dev/<disk>"; exit 1; }
[[ -n "$DISK" && -b "$DISK" ]] || { echo "Usage: sudo $0 /dev/<disk>"; lsblk -d -o NAME,SIZE,MODEL; exit 1; }
[[ -d /sys/firmware/efi ]] || { echo "Not booted in UEFI mode; systemd-boot needs UEFI."; exit 1; }

# Ask everything up front so the rest runs unattended.
lsblk "$DISK"
read -rp "ERASE ALL DATA on $DISK? Type the disk path again to confirm: " CONFIRM
[[ "$CONFIRM" == "$DISK" ]] || { echo "Aborted."; exit 1; }
while :; do
  read -rsp "New password for $USER_NAME: " PASS; echo
  read -rsp "Repeat password: " PASS2; echo
  [[ -n "$PASS" && "$PASS" == "$PASS2" ]] && break
  echo "Empty or mismatched, try again."
done

export NIX_CONFIG="experimental-features = nix-command flakes"

sed -i "s|device = \".*\"; # install.sh|device = \"$DISK\"; # install.sh|" "$REPO/disko.nix"
grep -q "device = \"$DISK\"" "$REPO/disko.nix" || { echo "Failed to set disk in disko.nix"; exit 1; }

echo ">>> Partitioning $DISK"
nix run github:nix-community/disko/latest -- --yes-wipe-all-disks --mode destroy,format,mount "$REPO/disko.nix"

echo ">>> Detecting hardware"
nixos-generate-config --no-filesystems --show-hardware-config > "$REPO/hardware-configuration.nix"
if grep -qs 0x10de /sys/bus/pci/devices/*/vendor; then # PCI vendor ID of NVIDIA
  echo "    NVIDIA GPU found: enabling nvidia.nix"
  echo '{ imports = [ ./nvidia.nix ]; }' > "$REPO/gpu.nix"
fi

echo ">>> Installing (this takes a while)"
mkdir -p "$(dirname "$TARGET")"
cp -a "$REPO" "$TARGET"
nixos-install --no-root-passwd --flake "$TARGET#nixos"

echo "$USER_NAME:$PASS" | nixos-enter --root /mnt -c chpasswd
chown -R 1000:100 "/mnt/home/$USER_NAME" # uid from configuration.nix, gid of "users"

echo ">>> Done. Config is at ~/nixos-config on the new system. Remove the ISO and run: reboot"
