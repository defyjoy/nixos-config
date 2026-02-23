{ config, pkgs , ...}:

{
  home.username = "jroychowdhury";
  home.homeDirectory = "/home/jroychowdhury";
  home.stateVersion = "25.11";
 
  programs.zsh = {
    enable = true;

     # Nice defaults (optional but recommended)
    enableCompletion = true;
    autosuggestion.enable = true;  # zsh-autosuggestions
    syntaxHighlighting.enable = true; # zsh-syntax-highlighting (optional but great):
    # autosuggestions.enable = true;
    # syntaxHighlighting.enable = true;

    initContent = ''
      alias nrs="sudo nixos-rebuild switch"
      alias hi="Hello Joy! Nice to meet you!"
      alias nixls="sudo nix-env -p /nix/var/nix/profiles/system --list-generations"
      alias nixdel="sudo nix-env -p /nix/var/nix/profiles/system --delete-generations"
    '';

    oh-my-zsh = {
  	enable = true;
		
    	plugins = [
      	  "git"
      	  "globalias"
          "fzf"
    	];
		theme = "fino-time";
    };
  };

  home.packages = with pkgs; [
    zsh
    oh-my-zsh
    firefox

    fzf
    snapper
    btrfs-assistant
    btrfs-list
    btrfs-auto-snapshot
    snapper-gui
    code-cursor
  ];
}
