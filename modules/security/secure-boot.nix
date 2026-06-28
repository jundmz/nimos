# Secure Boot via lanzaboote (signed boot chain).
#
# STAGED -- this module is left COMMENTED OUT in flake.nix. Enabling it before
# you have generated and enrolled keys will make the machine unbootable.
# Procedure (see SECURITY.md):
#   1. nix shell nixpkgs#sbctl -c sbctl create-keys
#   2. Put the firmware into Secure Boot "Setup Mode" (clear/enroll keys in BIOS)
#   3. Uncomment ./modules/security/secure-boot.nix in flake.nix and rebuild
#   4. sbctl verify   (confirm the boot files are signed)
{ lib, inputs, ... }:

{
  imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];

  # lanzaboote replaces systemd-boot.
  boot.loader.systemd-boot.enable = lib.mkForce false;

  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
  };
}
