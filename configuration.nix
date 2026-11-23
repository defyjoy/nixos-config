{ pkgs, ... }:
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos";
  networking.networkmanager.enable = true;
  time.timeZone = "Asia/Kolkata";
  zramSwap.enable = true;

  # Desktop
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };
  fonts.packages = with pkgs; [
    nerd-fonts.comic-shanns-mono
    nerd-fonts.arimo
  ];
  programs.firefox.enable = true;

  users.users.joydeep = {
    isNormalUser = true;
    uid = 1000; # install.sh chowns /home/joydeep by this uid
    description = "joydeep roychowdhury";
    extraGroups = [ "wheel" "networkmanager" "docker" ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIHrD0bZaw6uahGoabxd1KP8WdbZrVbv40NsJUsgOAQ+4AAAAC3NzaDpkZWZ5am95 defyjoy-yubikey"
    ];
  };
  programs.zsh.enable = true;

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # YubiKey: gpg smartcard + ykman
  services.pcscd.enable = true;
  services.udev.packages = [ pkgs.yubikey-personalization ];

  virtualisation.docker.enable = true; # replaces OrbStack
  services.ollama.enable = true;

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-bak";
    users.joydeep = import ./home.nix;
  };

  system.stateVersion = "26.05";
}
