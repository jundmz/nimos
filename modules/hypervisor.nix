# The hypervisor host: libvirt + QEMU/KVM, GUI (virt-manager), UEFI (OVMF),
# vTPM (swtpm), virtiofs, and an isolated NAT network + default storage pool.
#
# Usage (mirrors modules/users.nix): import ./modules/hypervisor.nix "username"
#
# Security posture: QEMU runs as the unprivileged `qemu-libvirtd` user (DAC
# isolation), under a seccomp sandbox and a mount namespace. AppArmor sVirt is
# available as an upgrade once profiles are verified (see verbatimConfig).
username:
{ config, lib, pkgs, ... }:

let
  # Default isolated NAT network (virbr0), defined as a store file so we don't
  # depend on indentation-sensitive heredocs inside the activation script.
  defaultNetXml = pkgs.writeText "libvirt-default-net.xml" ''
    <network>
      <name>default</name>
      <forward mode='nat'/>
      <bridge name='virbr0' stp='on' delay='0'/>
      <ip address='192.168.122.1' netmask='255.255.255.0'>
        <dhcp>
          <range start='192.168.122.2' end='192.168.122.254'/>
        </dhcp>
      </ip>
    </network>
  '';
in
{
  virtualisation.libvirtd = {
    enable = true;
    onBoot = "ignore"; # don't auto-start guests at boot
    onShutdown = "shutdown"; # cleanly shut guests down on host poweroff

    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = false; # run QEMU as unprivileged qemu-libvirtd, not root
      swtpm.enable = true; # software TPM 2.0 for guests (Windows 11, etc.)
      ovmf = {
        enable = true;
        # OVMFFull = UEFI firmware with Secure Boot + TPM support for guests.
        packages = [ pkgs.OVMFFull.fd ];
      };
      vhostUserPackages = [ pkgs.virtiofsd ]; # virtiofs shared folders

      # Appended to /etc/libvirt/qemu.conf. Kept conservative so that VM startup
      # never fails: seccomp + mount namespace + don't persist chown changes.
      verbatimConfig = ''
        seccomp_sandbox = 1
        namespaces = [ "mount" ]
        remember_owner = 0

        # sVirt UPGRADE (optional): once AppArmor sVirt profiles are confirmed
        # working on this host, uncomment to mandatorily confine every guest.
        # Enabling these before profiles work will block ALL guests from starting.
        # security_driver = "apparmor"
        # security_default_confined = 1
        # security_require_confined = 1
      '';
    };
  };

  # GUI + helpers. virt-manager needs dconf for its settings backend.
  programs.virt-manager.enable = true;
  programs.dconf.enable = true;
  virtualisation.spiceUSBRedirection.enable = true; # USB redirect into guests

  environment.systemPackages = with pkgs; [
    virt-viewer # lightweight SPICE/VNC console
    spice-gtk
    swtpm
    virtiofsd
    qemu # provides qemu-img for converting raw/qcow2/vmdk/vdi/vhd images
  ];

  # The managing user joins libvirtd + kvm (NOT a generic world-accessible group).
  users.users.${username}.extraGroups = [ "libvirtd" "kvm" ];

  ##########################################################################
  # Ensure a usable default NAT network (virbr0, isolated from the LAN) and a
  # default storage pool exist, idempotently, after libvirtd starts. The pool
  # lives under /var/lib/libvirt/images which sits on the (encrypted) root.
  ##########################################################################
  systemd.services.libvirt-default-resources = {
    description = "Define libvirt default network and storage pool";
    after = [ "libvirtd.service" ];
    requires = [ "libvirtd.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.libvirt ];
    serviceConfig.Type = "oneshot";
    serviceConfig.RemainAfterExit = true;
    script = ''
      set -eu

      # --- default NAT network ---
      if ! virsh net-info default >/dev/null 2>&1; then
        virsh net-define ${defaultNetXml}
      fi
      virsh net-autostart default || true
      virsh net-start default || true

      # --- default dir storage pool ---
      if ! virsh pool-info default >/dev/null 2>&1; then
        virsh pool-define-as default dir --target /var/lib/libvirt/images
        virsh pool-build default || true
      fi
      virsh pool-autostart default || true
      virsh pool-start default || true
    '';
  };
}
