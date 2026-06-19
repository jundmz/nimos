# Usage: import ./users.nix "username"
# Returns a NixOS module that creates the given user account.
username:

{ pkgs, ... }:

{
  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "input" "video" ];
    # shell = pkgs.zsh;
    # Replace with hashedPassword or remove for key-only auth
    initialPassword = "changeme";
  };
}
