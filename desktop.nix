# System side of the Niri + Noctalia desktop from defyjoy/.dotfiles (CachyOS packages/pacman.txt).
{ pkgs, inputs, ... }:
let
  # CachyOS's fish defaults, which the dotfiles' config.fish sources.
  cachyosFish = pkgs.runCommand "cachyos-fish-config" { } ''
    cp -r ${inputs.cachyos-fish-config} $out
    chmod -R u+w $out
    substituteInPlace $out/cachyos-config.fish \
      --replace-fail /usr/share/cachyos-fish-config $out
  '';
in
{
  programs.niri.enable = true;
  programs.noctalia = {
    enable = true;
    recommendedServices.enable = true; # NetworkManager, bluetooth, upower, power-profiles-daemon
  };
  services.displayManager.cosmic-greeter.enable = true; # pick the niri session

  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };
  programs.dconf.enable = true;
  services.gvfs.enable = true; # Nautilus trash/mounts
  services.gnome.gnome-keyring.enable = true;
  services.gnome.gcr-ssh-agent.enable = false; # gpg-agent is the ssh-agent
  hardware.logitech.wireless = {
    enable = true; # Solaar + udev rules for the MX Master 3
    enableGraphical = true;
  };
  programs.steam.enable = pkgs.stdenv.hostPlatform.isx86_64;

  # The dotfiles are mutable copies (see home-desktop.nix), so they point at
  # these stable /etc paths rather than store paths that GC would delete.
  environment.etc."cachyos-fish-config".source = cachyosFish;
  environment.etc."alacritty-themes".source = "${pkgs.alacritty-theme}/share/alacritty-theme";

  environment.systemPackages = with pkgs; [
    alacritty
    nautilus
    xwayland-satellite
    bibata-cursors
    papirus-icon-theme
    libsForQt5.qt5ct
    kdePackages.qt6ct
    libnotify # fish `done` notifications
    glib # gsettings, used by the cursor-theme fish function
    pavucontrol
  ];

  fonts.packages = with pkgs; [
    inter
    adwaita-fonts
    cantarell-fonts
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    nerd-fonts.jetbrains-mono
    nerd-fonts.meslo-lg
    nerd-fonts.comic-shanns-mono
    nerd-fonts.arimo
    dejavu_fonts
    liberation_ttf
    open-sans
  ];
}
