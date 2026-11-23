# Single-disk UEFI layout: 1G ESP + btrfs (subvolumes like CachyOS). Swap is zram (configuration.nix).
{
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/sda"; # install.sh rewrites this line to the disk you pass it
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "btrfs";
            extraArgs = [ "-f" ];
            subvolumes =
              let
                opts = [ "compress=zstd" "noatime" ];
              in
              {
                "@" = { mountpoint = "/"; mountOptions = opts; };
                "@home" = { mountpoint = "/home"; mountOptions = opts; };
                # snapper's `home` config needs /home/.snapshots to be a subvolume
                "@home-snapshots" = { mountpoint = "/home/.snapshots"; mountOptions = opts; };
                "@nix" = { mountpoint = "/nix"; mountOptions = opts; };
                "@log" = { mountpoint = "/var/log"; mountOptions = opts; };
              };
          };
        };
      };
    };
  };
}
