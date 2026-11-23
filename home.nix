# CLI tools, zsh, git and gpg ported from the macOS setup. Desktop configs: home-desktop.nix.
{ lib, pkgs, ... }:
{
  home.stateVersion = "26.05";

  home.packages = with pkgs; [
    # CLI
    bat bun coreutils eza gh git-filter-repo go go-task gpg-tui kubernetes-helm kubecolor
    kubectx kubectl lazyssh micro nodejs llama-cpp openbao terraform terragrunt
    yubikey-manager uv awscli2 argocd tldr tmux postgresql claude-code

    # GUI (terminal is Alacritty, from desktop.nix)
    zed-editor
  ] ++ lib.optionals stdenv.hostPlatform.isx86_64 [
    # x86_64 Linux only; skipped on the M1 Ultra (aarch64). Chrome/Slack have no aarch64 build,
    # the rest are heavy extras (~5 GB) not wanted there.
    google-chrome slack qemu lima google-cloud-sdk dbeaver-bin calibre
  ];

  home.sessionPath = [ "$HOME/.local/bin" "$HOME/.cargo/bin" "$HOME/go/bin" ];
  home.sessionVariables.COLORTERM = "truecolor";

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    oh-my-zsh = {
      enable = true;
      # zinit plugin list minus macOS/Fedora-only ones (dnf, command-not-found)
      plugins = [
        "git" "heroku" "pip" "sudo" "docker" "helm" "kubectl" "globalias" "terraform"
        "tldr" "uv" "vscode" "autojump" "zsh-interactive-cd" "aliases" "argocd" "aws"
        "common-aliases" "cp" "docker-compose" "extract" "eza" "fzf"
      ];
      extraConfig = ''
        zstyle ':omz:plugins:eza' 'show-group' no
        zstyle ':omz:plugins:eza' 'icons' yes
        zstyle ':omz:plugins:eza' 'dirs-first' yes
        zstyle ':omz:plugins:eza' 'git-status' yes
        zstyle ':omz:plugins:eza' 'header' no
        zstyle ':omz:plugins:eza' 'time-style' 'default'
        zstyle ':omz:plugins:eza' 'hyperlink' no
        zstyle ':omz:plugins:eza' 'color-scale' age
      '';
    };
    shellAliases = {
      k = "kubecolor";
      t = "terragrunt";
      tsc = "terragrunt stack clean";
      tsp = "terragrunt stack run plan";
      tsg = "terragrunt stack generate";
      tsa = "terragrunt stack run apply --non-interactive";
      cat = "bat";
    };
    initContent = ''
      # Merge kubeconfigs in ~/.kube (config, *.yaml, *.yml only)
      kubeconfigs=(~/.kube/(config|*.yaml|*.yml)(N.))
      (( ''${#kubeconfigs} )) && export KUBECONFIG=''${(j.:.)kubeconfigs}
      unset kubeconfigs
    '';
  };

  programs.starship.enable = true; # config: ~/.config/starship.toml from .dotfiles
  programs.atuin = {
    enable = true;
    settings.enter_accept = true;
  };
  programs.zoxide.enable = true;
  programs.autojump.enable = true;
  programs.fzf.enable = true;

  home.file.".tmux.conf".source = ./files/tmux.conf;
  # Read-only symlink: change Zed settings here, not in the Zed UI.
  xdg.configFile."zed/settings.json".source = ./files/zed-settings.json;

  programs.git = {
    enable = true;
    ignores = [ "**/.claude/settings.local.json" ];
    settings = {
      user = {
        name = "joydeep roychowdhury";
        email = "1047068+defyjoy@users.noreply.github.com";
      };
      init.defaultBranch = "main";
      log.showSignature = true;
    };
    # Signed commits for repos under these GitHub orgs (was ~/.gitconfig-defyjoy)
    includes = map (org: {
      condition = "hasconfig:remote.*.url:git@github.com:${org}/**";
      contents = {
        user = {
          name = "joydeep";
          signingkey = "0B60C9CA8BC08E22";
        };
        commit.gpgsign = true;
        tag.gpgsign = true;
      };
    }) [ "defyjoy" "Crypto-AI-Bot" ];
  };

  programs.gpg.enable = true;
  # Same as .dotfiles home/.gnupg/gpg-agent.conf: gpg-agent is the ssh-agent (YubiKey card key)
  services.gpg-agent = {
    enable = true;
    enableSshSupport = true;
    pinentry.package = pkgs.pinentry-qt;
    defaultCacheTtl = 600;
    maxCacheTtl = 7200;
  };
}
