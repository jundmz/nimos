{ pkgs, ... }:

{
  # ── direnv + nix-direnv ───────────────────────────────────────────────────────
  # nix-direnv: fast, cached `use flake` / `use nix` for direnv
  programs.direnv = {
    enable               = true;
    nix-direnv.enable    = true;
    enableZshIntegration = true;
    # Silence direnv output in the shell prompt area
    config.global.hide_env_diff = true;
  };

  # ── nix-index ────────────────────────────────────────────────────────────────
  # Replaces command-not-found with "nix-locate" and "nix run" suggestions.
  # Run `nix-index` once after install to build the database (~500 MB, ~10 min).
  programs.nix-index = {
    enable               = true;
    enableZshIntegration = true;
  };

  # ── fzf – fuzzy finder ───────────────────────────────────────────────────────
  programs.fzf = {
    enable               = true;
    enableZshIntegration = true;   # Ctrl-R history, Ctrl-T file, Alt-C cd
    defaultOptions       = [ "--height=40%" "--border=rounded" "--layout=reverse" "--info=inline" ];
    defaultCommand       = "fd --type f --hidden --follow --exclude .git";
    fileWidgetCommand    = "fd --type f --hidden --follow --exclude .git";
    changeDirWidgetCommand = "fd --type d --hidden --follow --exclude .git";
  };

  # ── bat – syntax-highlighted cat ─────────────────────────────────────────────
  programs.bat = {
    enable = true;
    config = {
      theme  = "Catppuccin Mocha";   # requires catppuccin bat theme; falls back if missing
      style  = "numbers,changes,header";
      pager  = "less -FR";
    };
    # Catppuccin Mocha theme for bat
    themes = {
      "Catppuccin Mocha" = {
        src  = pkgs.fetchFromGitHub {
          owner  = "catppuccin";
          repo   = "bat";
          rev    = "d2bbee4f7e7d5bac63c054e4d8eca57954b31471";
          sha256 = "sha256-x1yqPCWuoBSx/cI94eA+AWwhiSA42cLNUOFJl7qjhmw=";
        };
        file = "themes/Catppuccin Mocha.tmTheme";
      };
    };
  };

  # ── zoxide – smart cd ────────────────────────────────────────────────────────
  # Shell hook (`eval "$(zoxide init zsh --cmd cd)"`) lives in shell.nix
  programs.zoxide.enable = true;

  # ── CLI tools without dedicated HM program modules ────────────────────────────
  home.packages = with pkgs; [
    fd        # fast find (also used by fzf above)
    ripgrep   # fast grep (rg)
    jq        # JSON processor / pretty-printer
    eza       # modern ls with icons and git status
    unzip
    tree
  ];
}
