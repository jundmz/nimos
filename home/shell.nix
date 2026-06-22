{
  config,
  lib,
  pkgs,
  ...
}:

{

  # let

  #   nrp = writeShellScriptBin "nrp" ''

  #         git init && git add * && git commit -m "playing with this project" && gh repo create "$(basename "$PWD")" --public --source=. --remote=origin --push

  #     '';

  #   in
  #   {
  #   home.packages = [
  #     nrp
  #   ];

  #     home.sessionVariables = {
  #     EDITOR = "hx";
  #     VISUAL = "hx";
  #     PAGER = "bat";
  #     MANPAGER = "bat --language=man --style=plain";
  #     LESS = "-FR";
  #     FZF_DEFAULT_COMMAND = "fd --type f";
  # };

  # };
  #
  programs.tmux = {
    enable = true;
    tmuxinator.enable = true;
    plugins = with pkgs.tmuxPlugins; [
      {
        # https://github.com/fcsonline/tmux-thumbs#user-content-configuration
        plugin = tmux-thumbs;
        extraConfig = "";
      }
      #       {
      # # https://github.com/tmux-plugins/tmux-fpp
      #         plugin = open;
      #         extraConfig = ''
      #         set -g @open 'x'
      #         set -g @open-editor 'C-x'
      #         set -g @open-B 'https://www.bing.com/search?q='
      #         set -g @open-S 'https://www.google.com/search?q='
      #         '';
      #       }
      {
        plugin = tmux-fzf;
      }
      {
        # https://github.com/wfxr/tmux-fzf-url
        plugin = fzf-tmux-url;
        extraConfig = ''
          # set -g @fzf-url-bind 'x'
          set -g @fzf-url-fzf-options '-p 60%,30% --prompt="   " --border-label=" Open URL "'
          set -g @fzf-url-history-limit '2000'
        '';
      }
      # {
      # # https://github.com/dominikduda/tmux_mode_indicator
      # # https://github.com/MunifTanjim/tmux-mode-indicator
      # # https://github.com/tmux-plugins/tmux-prefix-highlight
      #   plugin = prefix-highlight;
      #   extraConfig = ''

      #     set -g @prefix_highlight_fg 'white' # default is 'colour231'
      #     set -g @prefix_highlight_bg 'blue'  # default is 'colour04'

      #      '';
      #  }
      #  {
      #   plugin = jump;
      #   extraConfig = ''
      #     set -g @jump-key ';'
      #     # keys will overlap with the word (default)
      #     set -g @jump-keys-position 'left'
      #     # keys will be at the left of the word without overlap
      #     set -g @jump-keys-position 'off_left'
      #     set -g @jump-bg-color '\e[0m\e[90m'
      #     set -g @jump-fg-color '\e[1m\e[31m'
      #   '';
      # }
      {
        # https://github.com/tmux-plugins/tmux-copycat
        # https://github.com/roosta/tmux-fuzzback
        plugin = extrakto;
        # extraConfig = ''
        #   set -g @extrakto_split_size "15"
        #   set -g @extrakto_clip_tool "xsel --input --clipboard" # works better for nvim
        #   set -g @extrakto_copy_key "tab"      # use tab to copy to clipboard
        #   set -g @extrakto_insert_key "enter"  # use enter to insert selection
        #   set -g @extrakto_fzf_unset_default_opts "false"  # keep our custom FZF_DEFAULT_OPTS
        #   set -g @extrakto_fzf_header "i c f g" # for small screens shorten the fzf header
        # '';
      }
      yank
      tilish
      # {
      #   plugin = inputs.tmux-sessionx.packages.${pkgs.system}.default;
      #   extraConfig = ''
      #     set -g @sessionx-zoxide-mode 'on'
      #     set -g @sessionx-bind 'o'
      #     set -g @sessionx-window-height '85%'
      #     set -g @sessionx-window-width '75%'
      #     set -g @sessionx-preview-location 'right'
      #     set -g @sessionx-preview-ratio '55%'
      #     set -g @sessionx-filter-current 'false'

      #     set -g @sessionx-bind-tree-mode 'ctrl-w'
      #     set -g @sessionx-bind-new-window 'ctrl-c'
      #     set -g @sessionx-bind-kill-session 'ctrl-d'        '';
      # }
    ];
    # prefix = "C-Space";
    shell = "${pkgs.zsh}/bin/zsh";
    extraConfig = with builtins; readFile ../config/tmux/tmux.conf;
  };
  # ── ZSH ─────────────────────────────────────────────────────────────────────
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    historySubstringSearch.enable = true;
    history = {
      size = 50000;
      save = 50000;
      ignoreDups = true;
      share = true;
    };
    shellAliases = {
      ls = "eza --icons";
      ll = "eza -la --icons --git";
      la = "eza -la --icons";
      cat = "bat";
      gs = "git status";
      gd = "git diff";
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
      add_newline = false;
      command_timeout = 1000;
      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
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
    enable = true;
    userName = lib.mkDefault config.home.username;
    userEmail = lib.mkDefault "${config.home.username}@nixos";
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
      diff.colorMoved = "default";
    };
    # git-delta: syntax-highlighted diffs
    delta = {
      enable = true;
      options = {
        navigate = true;
        side-by-side = true;
        line-numbers = true;
      };
    };
  };
}
