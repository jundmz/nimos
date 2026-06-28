# Usage: import ./users.nix "username"
# Returns a NixOS module that creates the given user account.
#
# Hardened: immutable users (no out-of-band passwd changes), no plaintext
# password in git -- the hash comes from sops (see modules/security/secrets.nix),
# and root login is locked.
username:

{ config, lib, pkgs, ... }:

{
  # Declarative-only accounts. NOTE: with this on, the user has NO password
  # until the sops secret exists. Create secrets/secrets.yaml BEFORE the first
  # `nixos-rebuild switch` (see SECURITY.md), or temporarily set this to true.
  users.mutableUsers = false;

  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "input"
      "video"
    ]; # "libvirtd"/"kvm" are added by modules/hypervisor.nix
    hashedPasswordFile = config.sops.secrets."${username}-password".path;
    # Add your SSH key for key-only login over the VPN:
    # openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAA... you@host" ];
  };

  # Lock the root account; administration is via wheel + sudo.
  users.users.root.hashedPassword = "!";
}
