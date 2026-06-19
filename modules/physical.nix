{ lib, ... }:

{
  # Bootloader (UEFI)
  boot.loader.systemd-boot.enable = lib.mkDefault true;
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;

  # Firmware & microcode
  hardware.enableRedistributableFirmware = true;
  hardware.cpu.intel.updateMicrocode = lib.mkDefault false;
  hardware.cpu.amd.updateMicrocode = lib.mkDefault false;

  # Power management
  services.thermald.enable = lib.mkDefault true;

  # Sound (PipeWire)
  services.pipewire = {
    enable = lib.mkDefault true;
    alsa.enable = true;
    pulse.enable = true;
  };
}
