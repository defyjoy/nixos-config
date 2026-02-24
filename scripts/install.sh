if ! mountpoint -q /mnt; then
  echo "mounting /dev/sda3 to /mnt"
  sudo mount /dev/sda3 /mnt
else
  echo "/mnt already mounted, skipping"
fi

# echo "installing git and chezmoi"
# sudo nix-shell -p git chezmoi

# echo "initializing chezmoi"
# chezmoi init --apply opsquark # this would clone into ~/.local/share/chezmoi in nixos iso home directory

if ! mountpoint -q /mnt/home; then
  echo "mounting /dev/sda2 to /mnt/home"
  sudo mount --mkdir /dev/sda2 /mnt/home
else
  echo "/mnt/home already mounted, skipping"
fi
if ! mountpoint -q /mnt/boot; then
  echo "mounting /dev/sda1 to /mnt/boot"
  sudo mount --mkdir /dev/sda1 /mnt/boot
else
  echo "/mnt/boot already mounted, skipping"
fi
if ! mountpoint -q /sys/firmware/efi/efivars; then
  echo "mounting efivarfs"
  sudo mount -t efivarfs efivarfs /sys/firmware/efi/efivars
else
  echo "efivarfs already mounted, skipping"
fi

echo "applying chezmoi configuration"
sudo chezmoi apply --source ~/.local/share/chezmoi --destination /mnt

echo "generating hardware configuration"
sudo nixos-generate-config --root /mnt --show-hardware-config > /mnt/etc/nixos/hardware-configuration.nix

echo "installing nixos to /mnt"
sudo nixos-install --root /mnt

echo "setting password for user(jroychowdhury)"
nixos-enter --root /mnt -c 'passwd jroychowdhury'

echo "rebooting"
sudo reboot

