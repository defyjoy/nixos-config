# RTX 4070 Super (open kernel module), as on the CachyOS desktop.
{ config, ... }:
{
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    open = true;
    modesetting.enable = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
  # PowerMizer fix from .dotfiles system/etc/modprobe.d/nvidia-power.conf
  boot.extraModprobeConfig = ''
    options nvidia NVreg_RegistryDwords="PowerMizerEnable=0x1; PerfLevelSrc=0x2222; PowerMizerDefaultAC=0x1"
  '';
  hardware.nvidia-container-toolkit.enable = true;
}
