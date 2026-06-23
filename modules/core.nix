{ lib, pkgs, ... }:

{
  # Nix settings
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
    "local-overlay-store"
  ];
  nix.settings.auto-optimise-store = true;

  # Locale & timezone (override per-host with mkForce or in host module)
  time.timeZone = lib.mkDefault "UTC";
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";

  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  programs.niri = {
    enable = true;

  };
  # Common system packages
  environment.systemPackages = with pkgs; [
    helix
    gh
    git
    tree
    curl
    htop
  ];

  # Networking
  networking.networkmanager.enable = lib.mkDefault true;

  system.stateVersion = "26.11";
}
