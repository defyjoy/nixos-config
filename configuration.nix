{ pkgs, inputs, ... }:
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [ "quiet" "splash" "nowatchdog" ]; # from .dotfiles limine cmdline
  boot.plymouth.enable = true;

  networking.hostName = "nixos";
  networking.networkmanager.enable = true;
  time.timeZone = "Asia/Kolkata";
  i18n.defaultLocale = "en_IN"; # .dotfiles locale.conf: en_IN.UTF-8 everywhere (glibc names it en_IN)
  zramSwap.enable = true;

  # DNS over TLS to Cloudflare (.dotfiles system/etc/systemd/resolved.conf).
  # Domains=~. sends every lookup here instead of DHCP-pushed DNS (replaces the nmcli step).
  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNS = [ "1.1.1.1#cloudflare-dns.com" ];
      DNSOverTLS = true;
      Domains = [ "~." ];
    };
  };

  users.users.defyjoy = {
    isNormalUser = true;
    uid = 1000; # install.sh chowns /home/defyjoy by this uid
    description = "joydeep roychowdhury";
    extraGroups = [ "wheel" "networkmanager" "docker" ];
    shell = pkgs.fish;
    openssh.authorizedKeys.keys = [
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIHrD0bZaw6uahGoabxd1KP8WdbZrVbv40NsJUsgOAQ+4AAAAC3NzaDpkZWZ5am95 defyjoy-yubikey"
    ];
  };
  programs.fish.enable = true;
  programs.zsh.enable = true;

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # YubiKey: gpg's built-in CCID driver (no pcscd, as in .dotfiles) + FIDO2 for ssh
  hardware.gpgSmartcards.enable = true;
  services.udev.packages = [ pkgs.yubikey-personalization pkgs.libfido2 ];

  # Snapper on /home, same limits as .dotfiles system/etc/snapper/configs/home
  services.snapper.configs.home = {
    SUBVOLUME = "/home";
    ALLOW_USERS = [ "defyjoy" ];
    SYNC_ACL = true;
    SPACE_LIMIT = "0.5";
    FREE_LIMIT = "0.2";
    NUMBER_CLEANUP = true;
    NUMBER_LIMIT = 50;
    NUMBER_LIMIT_IMPORTANT = 10;
    TIMELINE_CREATE = true;
    TIMELINE_CLEANUP = true;
    TIMELINE_LIMIT_HOURLY = 5;
    TIMELINE_LIMIT_DAILY = 7;
    TIMELINE_LIMIT_WEEKLY = 0;
    TIMELINE_LIMIT_MONTHLY = 0;
    TIMELINE_LIMIT_QUARTERLY = 0;
    TIMELINE_LIMIT_YEARLY = 0;
    EMPTY_PRE_POST_CLEANUP = true;
  };

  virtualisation.docker.enable = true;
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
    extraSpecialArgs = { inherit inputs; };
    users.defyjoy.imports = [ ./home.nix ./home-desktop.nix ];
  };

  system.stateVersion = "26.05";
}
