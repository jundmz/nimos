{ config, lib, pkgs, ... }:

{

  let

    nrp = writeShellScriptBin "nrp" ''

          set -e

          REPO_NAME="$(basename "$PWD")"

          gh repo create "$REPO_NAME" --public

          git init
          git add .
          git commit -m "playing with this project"
          git branch -M main

          USER=$(gh api user -q .login)

          git remote add origin "https://github.com/$USER/$REPO_NAME.git"

          git push -u origin main

      '';

    in
    {
    home.packages = [
      nrp
    ];

      home.sessionVariables = {
      EDITOR = "hx";
      VISUAL = "hx";
      PAGER = "bat";
      MANPAGER = "bat --language=man --style=plain";
      LESS = "-FR";
      FZF_DEFAULT_COMMAND = "fd --type f";
  };
    
  };
  # ── ZSH ─────────────────────────────────────────────────────────────────────
  programs.zsh = {
    enable = true;
    autosuggestion.enable      = true;
    syntaxHighlighting.enable  = true;
    historySubstringSearch.enable = true;
    history = {
      size       = 50000;
      save       = 50000;
      ignoreDups = true;
      share      = true;
    };
    shellAliases = {
      ls  = "eza --icons";
      ll  = "eza -la --icons --git";
      la  = "eza -la --icons";
      cat = "bat";
      gs  = "git status";
      gd  = "git diff";
    };
    initExtra = ''
      # zoxide replaces cd (use plain `cd` to jump; `cdi` for interactive)
      eval "$(zoxide init zsh --cmd cd)"
      eval "$(fzf --zsh)"
    '';
  };

  # ── Starship prompt ──────────────────────────────────────────────────────────
  programs.starship = {
    enable = true;
    settings = {
      add_newline     = false;
      command_timeout = 1000;
      character = {
        success_symbol = "[❯](bold green)";
        error_symbol   = "[❯](bold red)";
      };
      directory.truncation_length = 4;
      git_branch.symbol = " ";
      nix_shell = {
        symbol = " ";
        format = "via [$symbol$state( \\($name\\))]($style) ";
      };
    };
  };

  # ── Git ──────────────────────────────────────────────────────────────────────
  programs.git = {
    enable    = true;
    userName  = lib.mkDefault config.home.username;
    userEmail = lib.mkDefault "${config.home.username}@nixos";
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase        = true;
      diff.colorMoved    = "default";
    };
    # git-delta: syntax-highlighted diffs
    delta = {
      enable  = true;
      options = {
        navigate      = true;
        side-by-side  = true;
        line-numbers  = true;
      };
    };
  };
}
