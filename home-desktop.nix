# User side of the Niri + Noctalia desktop: the defyjoy/.dotfiles `home/` tree, adapted to NixOS.
{ lib, pkgs, inputs, osConfig, ... }:
let
  # Same files as .dotfiles home/, with CachyOS paths swapped for stable NixOS ones.
  dotfiles = pkgs.runCommand "dotfiles-home" { } ''
    cp -r ${inputs.dotfiles}/home $out
    chmod -R u+w $out
    cd $out
    # Managed by home-manager instead: gpg-agent (home.nix), zsh (home.nix), pywalfox host (below)
    rm -r .gnupg .zshrc .mozilla
    substituteInPlace .config/fish/config.fish \
      --replace-fail /usr/share/cachyos-fish-config /etc/cachyos-fish-config
    substituteInPlace .config/fish/functions/alacritty-theme.fish \
      --replace-fail /usr/lib/node_modules/alacritty-themes/themes /etc/alacritty-themes
    substituteInPlace .config/fish/functions/cursor-theme.fish \
      --replace-fail /usr/share/icons/ /run/current-system/sw/share/icons/
    # zen-browser-flake names the binary/desktop file zen-beta
    substituteInPlace .config/niri/cfg/keybinds.kdl --replace-fail '"zen-browser"' '"zen-beta"'
    substituteInPlace .config/mimeapps.list --replace-fail zen.desktop zen-beta.desktop
  '';
in
{
  # Copied, not symlinked: Noctalia and Solaar rewrite these files (see .dotfiles README).
  # Existing files are left alone; `dotfiles-apply` force-overwrites them.
  home.activation.seedDotfiles = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${pkgs.rsync}/bin/rsync -a --ignore-existing --chmod=u+w ${dotfiles}/ "$HOME/"
    run chmod 700 "$HOME/.ssh"
    run chmod 600 "$HOME/.ssh/config"
  '';

  home.packages = with pkgs; [
    (writeShellScriptBin "dotfiles-apply" ''
      # Overwrite live configs with the pinned .dotfiles; replaced files go to ~/.dotfiles-backup
      exec ${rsync}/bin/rsync -a --chmod=u+w \
        --backup --backup-dir="$HOME/.dotfiles-backup/$(date +%F-%H%M%S)" ${dotfiles}/ "$HOME/"
    '')
    inputs.zen-browser.packages.${stdenv.hostPlatform.system}.default
    btop fastfetch ripgrep duf glances meld vlc lima hwinfo unzip wget rsync
  ];

  # .dotfiles gsettings.txt
  dconf.settings."org/gnome/desktop/interface" = {
    cursor-size = 24;
    cursor-theme = "Bibata-Modern-Ice";
    document-font-name = "Inter 11";
    font-antialiasing = "grayscale";
    font-hinting = "slight";
    font-name = "Inter 11";
    icon-theme = "Papirus-Dark";
    monospace-font-name = "Adwaita Mono 11";
  };

  programs.firefox = {
    enable = true;
    profiles.default = {
      userChrome = builtins.readFile "${inputs.dotfiles}/browser/firefox/chrome/userChrome.css";
      userContent = builtins.readFile "${inputs.dotfiles}/browser/firefox/chrome/userContent.css";
      extraConfig = builtins.readFile "${inputs.dotfiles}/browser/firefox/user.js";
    };
    # Noctalia is the Pywalfox native host; install the Pywalfox extension in Firefox.
    nativeMessagingHosts = [
      (pkgs.writeTextDir "lib/mozilla/native-messaging-hosts/pywalfox.json" (builtins.toJSON {
        name = "pywalfox";
        description = "Noctalia Firefox theme native messaging host";
        path = lib.getExe osConfig.programs.noctalia.package;
        type = "stdio";
        allowed_extensions = [ "pywalfox@frewacom.org" ];
      }))
    ];
  };
}
