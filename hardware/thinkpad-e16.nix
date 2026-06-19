{ config, lib, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ../disko/ext4.nix
  ];

  networking.hostName = "thinkpad-e16";

  boot.initrd.availableKernelModules = [ ];
  boot.kernelModules = [ ];

  # ThinkPad E16-specific overrides (nixos-hardware module, CPU microcode, etc.) go here
}
