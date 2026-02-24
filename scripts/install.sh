echo "mounting /dev/sda3 to /mnt"
sudo mount /dev/sda3 /mnt

# echo "installing git and chezmoi"
# sudo nix-shell -p git chezmoi

# echo "initializing chezmoi"
# chezmoi init --apply opsquark # this would clone into ~/.local/share/chezmoi in nixos iso home directory

echo "mounting home, boot, and efivarfs"
sudo mount --mkdir /dev/sda2 /mnt/home
sudo mount --mkdir /dev/sda1 /mnt/boot
sudo mount -t efivarfs efivarfs /sys/firmware/efi/efivars

echo "applying chezmoi configuration"
sudo chezmoi apply --source ~/.local/share/chezmoi --destination /

echo "generating hardware configuration"
sudo nixos-generate-config --root /mnt --show-hardware-config > /mnt/etc/nixos/hardware-configuration.nix

echo "installing nixos to /mnt"
sudo nixos-install --root /mnt

echo "setting password for user(jroychowdhury)"
nixos-enter --root /mnt -c 'passwd jroychowdhury'

echo "rebooting"
sudo reboot

