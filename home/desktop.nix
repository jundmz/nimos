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
  # ── Alacritty terminal ────────────────────────────────────────────────────────
  programs.alacritty = {
    enable = true;
    settings = {
      window = {
        opacity = 0.95;
        padding = {
          x = 8;
          y = 8;
        };
        dynamic_padding = true;
        decorations = "none";
      };
      font = {
        normal = {
          family = "monospace";
          style = "Regular";
        };
        bold = {
          family = "monospace";
          style = "Bold";
        };
        italic = {
          family = "monospace";
          style = "Italic";
        };
        size = 12.0;
        offset = {
          x = 0;
          y = 1;
        };
      };
      cursor = {
        style = {
          shape = "Beam";
          blinking = "On";
        };
        blink_interval = 600;
        unfocused_hollow = true;
      };
      # shell.program = "zsh";
      scrolling.history = 10000;
    };
  };
}
