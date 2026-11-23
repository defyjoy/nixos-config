# Single-disk UEFI layout: 1G ESP + ext4 root. Swap is zram (configuration.nix).
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
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
}
