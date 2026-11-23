# Placeholder so the flake evaluates before install.
# install.sh overwrites this with `nixos-generate-config --no-filesystems` output
# for the real machine (filesystems come from disko.nix).
{ lib, ... }:
{
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
