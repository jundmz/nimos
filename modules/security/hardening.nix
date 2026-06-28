# Host hardening for a KVM hypervisor.
#
# Threat model: the HOST is the trust anchor; guests are treated as hostile.
# This module is deliberately "virtualization-safe" hardening -- we do NOT use
# profiles/hardened.nix or linuxPackages_hardened, because they break things a
# hypervisor needs (user namespaces, on-demand module loading, KVM features).
{ lib, pkgs, ... }:

{
  ##########################################################################
  # Firewall: default-deny inbound. Nothing is opened globally here; each
  # host/role module opens only the ports it needs, scoped to an interface
  # (e.g. Cockpit/SSH are opened on the wg0 VPN interface only).
  ##########################################################################
  networking.nftables.enable = true;
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ ];
    allowedUDPPorts = [ ];
    logRefusedConnections = false;
  };
  # libvirt manages its own NAT/forward rules for the virbr* bridges; this is
  # compatible with the nftables backend.

  ##########################################################################
  # Kernel runtime hardening (curated -- nothing here breaks libvirt/QEMU).
  ##########################################################################
  boot.kernel.sysctl = {
    # Kernel pointer / log / dmesg exposure
    "kernel.kptr_restrict" = 2;
    "kernel.dmesg_restrict" = 1;
    "kernel.printk" = "3 3 3 3";
    "kernel.kexec_load_disabled" = 1;
    "kernel.unprivileged_bpf_disabled" = 1;
    "net.core.bpf_jit_harden" = 2;
    "kernel.perf_event_paranoid" = 2;
    "kernel.yama.ptrace_scope" = 1;
    "kernel.sysrq" = 4; # only allow the secure-attention key combos

    # Filesystem hardening
    "fs.protected_symlinks" = 1;
    "fs.protected_hardlinks" = 1;
    "fs.protected_fifos" = 2;
    "fs.protected_regular" = 2;
    "fs.suid_dumpable" = 0;

    # Network hardening
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.default.rp_filter" = 1;
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv4.conf.all.secure_redirects" = 0;
    "net.ipv4.conf.default.secure_redirects" = 0;
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.default.send_redirects" = 0;
    "net.ipv4.conf.all.accept_source_route" = 0;
    "net.ipv4.conf.default.accept_source_route" = 0;
    "net.ipv6.conf.all.accept_redirects" = 0;
    "net.ipv6.conf.default.accept_redirects" = 0;
    "net.ipv6.conf.all.accept_source_route" = 0;
    "net.ipv4.tcp_syncookies" = 1;
    "net.ipv4.icmp_echo_ignore_broadcasts" = 1;

    # IMPORTANT: deliberately NOT set, because they break the hypervisor:
    #   kernel.unprivileged_userns_clone = 0  -> breaks libvirt/QEMU + nix sandbox
    #   net.ipv4.ip_forward             = 0  -> libvirt enables forwarding per NAT network
  };

  ##########################################################################
  # Boot-time / kernel-image hardening.
  ##########################################################################
  boot.kernelParams = [
    "slab_nomerge"
    "init_on_alloc=1"
    "init_on_free=1"
    "page_alloc.shuffle=1"
    "randomize_kbase"
    "vsyscall=none"
    "debugfs=off"
    "nohibernate" # hibernation would leak guest RAM (incl. VM memory) to swap
    # "nosmt"     # OPT-IN: strongest cross-guest L1TF/MDS defense, but ~halves
    #             # throughput by disabling hyperthreading. Enable if running
    #             # untrusted guests and you can spare the performance.
  ];

  # Keep CPU vulnerability mitigations ON (never mitigations=off on a host that
  # runs hostile guests) and add hypervisor-relevant ones.
  security.forcePageTableIsolation = true;
  security.virtualisation.flushL1DataCache = "cond"; # KVM L1TF flush

  # Pre-load the modules libvirt/QEMU need on demand, so we don't have to keep
  # dynamic module loading wide open. We intentionally do NOT lock kernel
  # modules: a "run anything" hypervisor may need modules we can't predict.
  boot.kernelModules = [ "kvm-intel" "vhost_net" "vhost_vsock" "tun" "nbd" ];
  security.lockKernelModules = false; # documented tradeoff (see plan)

  # Blacklist obscure / DMA-attack-prone modules that a hypervisor never needs.
  boot.blacklistedKernelModules = [
    "dccp"
    "sctp"
    "rds"
    "tipc"
    "firewire-core"
    "firewire-ohci"
  ];

  ##########################################################################
  # Mandatory Access Control. AppArmor is enabled host-wide; sVirt/QEMU
  # confinement is configured in modules/hypervisor.nix.
  ##########################################################################
  security.apparmor = {
    enable = true;
    killUnconfinedConfinables = true;
  };

  ##########################################################################
  # Privilege escalation.
  ##########################################################################
  security.sudo = {
    execWheelOnly = true; # only wheel may use sudo at all
    extraConfig = ''
      Defaults lecture = never
      Defaults timestamp_timeout = 5
    '';
    # Memory-safe alternative: swap the two lines below for the ones above.
    # security.sudo.enable = false; security.sudo-rs.enable = true;
  };

  ##########################################################################
  # nix-daemon hardening.
  ##########################################################################
  nix.settings = {
    allowed-users = [ "@wheel" ];
    trusted-users = [ "root" ]; # NOT @wheel: a trusted user can own the store
    sandbox = true;
  };

  ##########################################################################
  # SSH: hardened, key-only, no root. No port is opened here -- role modules
  # open 22 on the interface they want (heavy6: wg0 only; dvm: see vmtweaks).
  ##########################################################################
  services.openssh = {
    enable = false;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      X11Forwarding = false;
    };
  };

  ##########################################################################
  # Misc.
  ##########################################################################
  boot.tmp.cleanOnBoot = true;
  zramSwap.enable = true; # encrypted-by-nature in-RAM swap; no plaintext on disk
}
