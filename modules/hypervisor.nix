username:
{ pkgs, ... }:
{
  virtualisation.libvirtd = {
    enable = true;
    qemu.swtpm.enable = true;          # vTPM for Win11
  };
  programs.virt-manager.enable = true;
  programs.dconf.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;

  environment.systemPackages = with pkgs; [
    virt-viewer spice-gtk swtpm virtiofsd qemu
  ];

  users.users.${username}.extraGroups = [ "libvirtd" "kvm" ];
}
