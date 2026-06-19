# Live config symlinks — edits take effect immediately, no rebuild needed.
#
# config.lib.file.mkOutOfStoreSymlink creates a symlink pointing to the REAL
# file on disk (not a Nix store path). Any edit to config/<tool>/<file> in the
# repo is instantly visible to the running program.
#
# The symlinks are (re-)created on the next `nixos-rebuild switch`. After that
# first activation they are live.
#
# To add more tools:
#   1. Create config/<tool>/<file> in the repo.
#   2. Add a home.file entry below following the same pattern.
#   3. Run `nixos-rebuild switch` once to create the new symlink.

{ config, ... }:

let
  # Assumes the repo is checked out at ~/hnc.
  # Adjust this path if the repo lives elsewhere on a specific machine.
  repo = "${config.home.homeDirectory}/hnc";
in
{
  # ── Tridactyl ──────────────────────────────────────────────────────────────
  # Tridactyl reads ~/.config/tridactyl/tridactylrc (XDG default on Linux).
  home.file.".config/tridactyl/tridactylrc".source =
    config.lib.file.mkOutOfStoreSymlink "${repo}/config/tridactyl/tridactylrc";

  # ── tmux ───────────────────────────────────────────────────────────────────
  # tmux >= 3.1 reads ~/.config/tmux/tmux.conf (XDG path).
  home.file.".config/tmux/tmux.conf".source =
    config.lib.file.mkOutOfStoreSymlink "${repo}/config/tmux/tmux.conf";
}
