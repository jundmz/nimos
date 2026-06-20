{ pkgs, ... }:

{
  # ── Helix modal editor ────────────────────────────────────────────────────────
  programs.helix = {
    enable = true;
    defaultEditor = true;   # sets $EDITOR and $VISUAL

    settings = {
      theme = "ao";

      editor = {
        line-number      = "relative";
        cursorline       = true;
        color-modes      = true;
        auto-pairs       = true;
        completion-trigger-len = 2;
        cursor-shape     = { insert = "bar"; normal = "block"; select = "underline"; };
        indent-guides    = { render = true; character = "╎"; };
        lsp              = { display-inlay-hints = true; display-messages = true; };
        statusline = {
          left   = [ "mode" "spinner" "file-name" "file-modification-indicator" ];
          center = [ "version-control" ];
          right  = [ "diagnostics" "selections" "position" "file-encoding" ];
        };
      };

      keys.normal = {
        "C-s"   = ":write";
        space.f = ":format";
        # Quick window splits
        "C-w" = {
          v = "vsplit";
          s = "hsplit";
        };
      };
      keys.insert."C-s" = [ ":write" "normal_mode" ];
    };

    languages = {
      language-server.nil = {
        command = "nil";   # nix LSP – install nil via home.packages or nix shell
      };
      language = [
        {
          name         = "nix";
          language-servers = [ "nil" ];
          formatter    = { command = "nixfmt"; };
          auto-format  = true;
        }
      ];
    };
  };

  # ── VS Code ───────────────────────────────────────────────────────────────────
  programs.vscode = {
    enable = false;
    userSettings = {
      "editor.fontSize"                    = 14;
      "editor.fontFamily"                  = "'JetBrains Mono', 'Fira Code', monospace";
      "editor.fontLigatures"               = true;
      "editor.formatOnSave"                = true;
      "editor.minimap.enabled"             = false;
      "editor.inlineSuggest.enabled"       = true;
      "editor.bracketPairColorization.enabled" = true;
      "editor.guides.bracketPairs"         = true;
      "editor.renderWhitespace"            = "boundary";
      "workbench.colorTheme"               = "Default Dark+";
      "workbench.iconTheme"                = "material-icon-theme";
      "terminal.integrated.defaultProfile.linux" = "zsh";
      "files.autoSave"                     = "onFocusChange";
      "git.autofetch"                      = true;
      "extensions.autoUpdate"              = false;   # declarative config: no auto-updates
    };
  };

  # ── Cursor (AI-powered VS Code fork) ─────────────────────────────────────────
  # Available as pkgs.code-cursor in nixpkgs-unstable.
  # Cursor syncs VS Code settings on first launch; the vscode settings above apply.
  # home.packages = [ pkgs.code-cursor ];

  # ── Emacs (TUI: emacs -nw  |  GUI: emacs on Wayland) ────────────────────────────
  programs.emacs = {
    enable  = true;
    package = pkgs.emacs-pgtk;           # pure-GTK: Wayland GUI + TUI (-nw)
    extraPackages = epkgs: [ epkgs.which-key ];

    # Thin loader only — real config lives in config/emacs/init.el (live-editable).
    # Edit that file and restart Emacs; no rebuild required.
    # extraConfig = ''
    #   (load (expand-file-name "~/${username}/config/emacs/init.el") nil :nomessage)
    # '';
  };

  # ── LSP / formatter helpers used by editors ───────────────────────────────────
  home.packages = [
    # pkgs.code-cursor
    pkgs.nil       # Nix language server (used by Helix + VS Code Nix extension)
    pkgs.nixfmt-rfc-style  # Nix formatter (`nixfmt`)
  ];
}
