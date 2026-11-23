# Ported from the macOS setup (brew leaves/casks, ~/.zshrc, ~/.zinit-plugins.zsh, dotfiles).
{ lib, pkgs, ... }:
let
  github = key: {
    HostName = "github.com";
    User = "git";
    IdentityFile = "~/.ssh/${key}";
  };
in
{
  home.stateVersion = "26.05";

  home.packages = with pkgs; [
    # CLI
    bun coreutils eza gh git-filter-repo go go-task gpg-tui kubernetes-helm kubecolor
    kubectx kubectl lazyssh micro nodejs llama-cpp openbao qemu terraform terragrunt
    yubikey-manager uv google-cloud-sdk awscli2 argocd tldr tmux postgresql claude-code
    (writeShellScriptBin "git-use" (builtins.readFile ./files/git-use))

    # GUI
    ghostty zed-editor dbeaver-bin calibre
  ] ++ lib.optionals stdenv.hostPlatform.isx86_64 [ google-chrome slack ]; # x86_64-only builds

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
      gu = "git-use";
    };
    initContent = ''
      # Merge kubeconfigs in ~/.kube (config, *.yaml, *.yml only)
      kubeconfigs=(~/.kube/(config|*.yaml|*.yml)(N.))
      (( ''${#kubeconfigs} )) && export KUBECONFIG=''${(j.:.)kubeconfigs}
      unset kubeconfigs
    '';
  };

  programs.starship.enable = true;
  xdg.configFile."starship.toml".source = ./files/starship.toml;
  programs.atuin = {
    enable = true;
    settings.enter_accept = true;
  };
  programs.zoxide.enable = true;
  programs.autojump.enable = true;
  programs.fzf.enable = true;
  programs.bat.enable = true;

  home.file.".tmux.conf".source = ./files/tmux.conf;
  xdg.configFile."ghostty/config".source = ./files/ghostty.config;
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
  services.gpg-agent = {
    enable = true;
    pinentry.package = pkgs.pinentry-gnome3;
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    # Private hosts (home lab etc.) live in ~/.ssh/config.local, outside git.
    includes = [ "config.local" ];
    settings = {
      # github.com points at a symlink that `git-use <profile>` swaps
      "github.com" = github "github-active";
      defyjoy = github "defyjoy";
    };
  };
}
