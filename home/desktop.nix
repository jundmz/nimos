{ config, pkgs, ... }:

# Wayland desktop: niri compositor + noctalia shell + alacritty terminal.
#
# System-level prerequisites (applied to mythbox in flake.nix):
#   inputs.niri-flake.nixosModules.niri  – installs niri + xdg-desktop-portal-gnome
#
# Home-Manager modules injected via mkHome in flake.nix:
#   inputs.niri-flake.homeModules.config – exposes programs.niri.settings
#   inputs.noctalia.homeModules.default  – exposes programs.noctalia

{
  # ── Niri compositor ──────────────────────────────────────────────────────────
  # Full option reference: https://github.com/sodiboo/niri-flake
  programs.niri.settings = {
    input = {
      keyboard.xkb = {
        layout  = "us";
        # options = "ctrl:nocaps";  # uncomment to swap CapsLock↔Ctrl at XKB level
      };
      touchpad = {
        tap                    = true;
        natural-scroll         = true;
        dwt                    = true;   # disable while typing
        accel-speed            = 0.2;
      };
      mouse.accel-speed = 0.0;
    };

    layout = {
      gaps = 8;
      center-focused-column = "never";
      preset-column-widths = [
        { proportion = 1.0 / 3.0; }
        { proportion = 0.5;       }
        { proportion = 2.0 / 3.0; }
      ];
      default-column-width = { proportion = 0.5; };
      focus-ring = {
        enable = true;
        width  = 2;
        active-color   = "#89b4fa";   # catppuccin blue
        inactive-color = "#313244";
      };
    };

    # Keybinds – Super (Mod) as primary modifier
    binds = with config.lib.niri.actions; {
      # Launchers
      "Mod+T".action       = spawn "alacritty";
      "Mod+Space".action   = spawn "fuzzel";
      "Mod+E".action       = spawn "nautilus";

      # Window management
      "Mod+Q".action       = close-window;
      "Mod+F".action       = fullscreen-window;
      "Mod+M".action       = maximize-column;
      "Mod+C".action       = center-column;

      # Focus movement
      "Mod+Left".action    = focus-column-left;
      "Mod+Right".action   = focus-column-right;
      "Mod+Up".action      = focus-workspace-up;
      "Mod+Down".action    = focus-workspace-down;
      "Mod+H".action       = focus-column-left;
      "Mod+L".action       = focus-column-right;
      "Mod+K".action       = focus-workspace-up;
      "Mod+J".action       = focus-workspace-down;

      # Move windows
      "Mod+Shift+Left".action    = move-column-left;
      "Mod+Shift+Right".action   = move-column-right;
      "Mod+Shift+H".action       = move-column-left;
      "Mod+Shift+L".action       = move-column-right;

      # Column width presets
      "Mod+R".action       = switch-preset-column-width;
      "Mod+Minus".action   = set-column-width "-5%";
      "Mod+Equal".action   = set-column-width "+5%";

      # Workspaces 1-5
      "Mod+1".action       = focus-workspace 1;
      "Mod+2".action       = focus-workspace 2;
      "Mod+3".action       = focus-workspace 3;
      "Mod+4".action       = focus-workspace 4;
      "Mod+5".action       = focus-workspace 5;
      "Mod+Shift+1".action = move-window-to-workspace 1;
      "Mod+Shift+2".action = move-window-to-workspace 2;
      "Mod+Shift+3".action = move-window-to-workspace 3;
      "Mod+Shift+4".action = move-window-to-workspace 4;
      "Mod+Shift+5".action = move-window-to-workspace 5;

      # Screenshot
      "Print".action       = screenshot;
      "Mod+Print".action   = screenshot-window;

      # Audio (PipeWire / wpctl)
      "XF86AudioRaiseVolume".action = spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+";
      "XF86AudioLowerVolume".action = spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-";
      "XF86AudioMute".action        = spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle";
      "XF86AudioMicMute".action     = spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SOURCE@" "toggle";

      # Brightness (brightnessctl)
      "XF86MonBrightnessUp".action   = spawn "brightnessctl" "set" "5%+";
      "XF86MonBrightnessDown".action = spawn "brightnessctl" "set" "5%-";

      # Session
      "Mod+Shift+E".action = quit;
    };

    window-rules = [
      {
        matches = [{ app-id = "alacritty"; }];
        default-column-width = { proportion = 0.5; };
      }
      {
        matches = [{ app-id = "org.gnome.Nautilus"; }];
        default-column-width = { proportion = 0.4; };
      }
    ];

    # Auto-start noctalia on login
    spawn-at-startup = [
      { command = [ "noctalia" ]; }
    ];
  };

  # ── Noctalia desktop shell ────────────────────────────────────────────────────
  # Provides top bar, notification daemon, and app launcher overlay.
  # Configured by programs.noctalia options from homeModules.default.
  # Full docs: https://docs.noctalia.dev
  programs.noctalia.enable = true;

  # ── Alacritty terminal ────────────────────────────────────────────────────────
  programs.alacritty = {
    enable = true;
    settings = {
      window = {
        opacity         = 0.95;
        padding         = { x = 8; y = 8; };
        dynamic_padding = true;
        decorations     = "none";
      };
      font = {
        normal   = { family = "monospace"; style = "Regular"; };
        bold     = { family = "monospace"; style = "Bold"; };
        italic   = { family = "monospace"; style = "Italic"; };
        size     = 12.0;
        offset   = { x = 0; y = 1; };
      };
      cursor = {
        style     = { shape = "Beam"; blinking = "On"; };
        blink_interval = 600;
        unfocused_hollow = true;
      };
      shell.program = "zsh";
      scrolling.history = 10000;
    };
  };
}
