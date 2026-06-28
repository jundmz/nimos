#!/usr/bin/env bash
# apply-nimos-hardening.sh
# Recreates the hardened GUI-hypervisor config in your local nimos repo.
# Usage:  bash apply-nimos-hardening.sh [path-to-nimos-repo]   (defaults to CWD)
set -euo pipefail

REPO="${1:-$PWD}"
BRANCH="hardening-hyperv"

cd "$REPO"
[ -f flake.nix ] || { echo "ERROR: no flake.nix in '$REPO'. Pass your nimos repo path as arg 1." >&2; exit 1; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "ERROR: '$REPO' is not a git repo." >&2; exit 1; }

echo ">> Repo:   $REPO"
echo ">> Branch: $BRANCH"
git checkout -B "$BRANCH"
mkdir -p modules/security secrets disko

write() { mkdir -p "$(dirname "$1")"; cat > "$1"; echo "   wrote $1"; }

write flake.nix <<'__NIMOS_EOF__'
{
  description = "NixOS configuration with home-manager and disko";

  nixConfig = {
    extra-substituters = [ "https://niri.cachix.org" ];
    extra-trusted-public-keys = [
      "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    niri-flake = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    palefox = {
      url = "github:tompassarelli/palefox";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      nixpkgs,
      home-manager,
      nixos-hardware,
      disko,
      ...
    }:
    let
      lib = nixpkgs.lib;

      mkHost =
        { system, modules }:
        lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs nixos-hardware disko; };
          modules = modules;
        };

      mkHome = username: hmConfigPath: [
        home-manager.nixosModules.home-manager
        # NUR overlay – required by palefox to install Sideberry from NUR
        { nixpkgs.overlays = [ inputs.nur.overlays.default ]; }
        {
          home-manager = {
            extraSpecialArgs = { inherit inputs; };
            useGlobalPkgs = true;
            useUserPackages = true;
            users.${username} = {
              imports = [
                hmConfigPath
                # inputs.niri-flake.homeModules.config        # programs.niri.settings
                # inputs.noctalia.homeModules.default         # programs.noctalia
                # inputs.palefox.homeManagerModules.default   # programs.palefox
              ];
              home.username = username;
              home.homeDirectory = "/home/${username}";
            };
          };
        }
      ];
    in
    {
      nixosConfigurations = {
        # ── ThinkPad E16 (daily driver) ─────────────────────────────
        heavy6 = mkHost {
          system = "x86_64-linux";
          modules = [
            disko.nixosModules.disko
            ./disko/ext4.nix
            # ./disko/luks-ext4.nix   # swap in for ext4.nix at reinstall for LUKS FDE
            ./hardware/thinkpad-e16.nix
            ./modules/core.nix
            ./modules/keyd.nix
            ./modules/physical.nix
            ./modules/vmtweaks.nix
            # ./modules/virtualization.nix

            # Security hardening (host = trust anchor, guests = hostile)
            ./modules/security/secrets.nix
            ./modules/security/hardening.nix
            ./modules/security/audit.nix
            ./modules/security/usbguard.nix
            # ./modules/security/secure-boot.nix   # enable AFTER sbctl key enrollment

            # Hypervisor stack + management surfaces
            (import ./modules/hypervisor.nix "jundmz")
            ./modules/cockpit.nix
            ./modules/vpn.nix

            (import ./modules/users.nix "jundmz")
            # inputs.niri-flake.nixosModules.niri   # niri pkg + xdg-portal-gnome
          ]
          ++ mkHome "jundmz" ./home;
        };

        dvm = mkHost {
          system = "x86_64-linux";
          modules = [
            ./modules/core.nix
            ./modules/keyd.nix
            ./modules/physical.nix
            ./modules/vmtweaks.nix
            # ./modules/virtualization.nix

            # Shared baseline hardening (guest VM -- no hypervisor/cockpit/usbguard)
            ./modules/security/secrets.nix
            ./modules/security/hardening.nix
            ./modules/security/audit.nix

            (import ./modules/users.nix "jundmz")
            # inputs.niri-flake.nixosModules.niri   # niri pkg + xdg-portal-gnome
          ]
          ++ mkHome "jundmz" ./home;
        };

              };

      # Reusable NixOS modules
      nixosModules = {
        physical = import ./modules/physical.nix;
        core = import ./modules/core.nix;
        keyd = import ./modules/keyd.nix;
      };
    };
}
__NIMOS_EOF__

write modules/security/secrets.nix <<'__NIMOS_EOF__'
# sops-nix wiring. Keeps all credentials OUT of git: the repo only ever holds
# the *encrypted* secrets/secrets.yaml, decrypted at activation by the host's
# SSH host key (converted to an age key).
#
# Bootstrap (see SECURITY.md): create secrets/secrets.yaml with `sops`, using
# the host key's age public key, before the first `nixos-rebuild switch`.
{ inputs, ... }:

{
  imports = [ inputs.sops-nix.nixosModules.sops ];

  sops.defaultSopsFile = ../../secrets/secrets.yaml;
  # The committed secrets.yaml starts as a placeholder; don't fail the build on
  # it. Decryption still happens at activation (and will require the real file).
  sops.validateSopsFiles = false;

  # Decrypt using the machine's SSH host key (no extra key material to manage).
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  # `neededForUsers` makes this available early enough for hashedPasswordFile.
  # (The dev-VM's "dev-password" secret is declared in modules/vmtweaks.nix,
  # scoped to the vmVariant where that user actually exists.)
  sops.secrets."jundmz-password".neededForUsers = true;
}
__NIMOS_EOF__

write modules/security/hardening.nix <<'__NIMOS_EOF__'
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
    enable = true;
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
__NIMOS_EOF__

write modules/security/audit.nix <<'__NIMOS_EOF__'
# Kernel audit framework + a hypervisor-focused ruleset.
{ ... }:

{
  security.auditd.enable = true;
  security.audit = {
    enable = true;
    rules = [
      # libvirt: watch config and state for tampering
      "-w /etc/libvirt/ -p wa -k libvirt-config"
      "-w /var/lib/libvirt/ -p wa -k libvirt-state"

      # privilege / account changes
      "-w /etc/sudoers -p wa -k sudo-config"
      "-w /etc/sudoers.d/ -p wa -k sudo-config"
      "-w /etc/ssh/sshd_config -p wa -k sshd-config"

      # every root-uid execve
      "-a always,exit -F arch=b64 -S execve -F euid=0 -k root-exec"

      # kernel module load/unload
      "-a always,exit -F arch=b64 -S init_module -S finit_module -S delete_module -k modules"
    ];
  };
}
__NIMOS_EOF__

write modules/security/usbguard.nix <<'__NIMOS_EOF__'
# USBGuard: block unknown USB devices (BadUSB / malicious-device protection).
#
# STAGED: this module is wired into heavy6, but read the caveats before relying
# on it. `presentDevicePolicy = "keep"` means devices already connected when the
# daemon starts (your built-in keyboard, etc.) stay authorized -- only NEW,
# hot-plugged devices are blocked by default. Generate a real allowlist with
#   usbguard generate-policy > /etc/usbguard/rules.conf
# (see SECURITY.md) and add allow-rules for any USB device you pass through to a
# VM, otherwise the guest cannot see it.
{ ... }:

{
  services.usbguard = {
    enable = true;
    implicitPolicyTarget = "block";
    presentDevicePolicy = "keep"; # don't lock out already-connected devices
    IPCAllowedUsers = [ "root" "jundmz" ];
    # rules = ''
    #   # paste output of `usbguard generate-policy` here, or manage
    #   # /etc/usbguard/rules.conf out-of-band.
    # '';
  };
}
__NIMOS_EOF__

write modules/security/secure-boot.nix <<'__NIMOS_EOF__'
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
__NIMOS_EOF__

write modules/hypervisor.nix <<'__NIMOS_EOF__'
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
__NIMOS_EOF__

write modules/cockpit.nix <<'__NIMOS_EOF__'
# Cockpit web UI for managing this hypervisor (and other nodes) over the VPN.
#
# Exposed ONLY on the wg0 VPN interface -- the port is firewalled off on the LAN
# and everywhere else. TLS is forced. Login is PAM-backed, so a user needs their
# (sops-managed) password and wheel membership for admin actions.
{ pkgs, ... }:

{
  services.cockpit = {
    enable = true;
    port = 9090;
    openFirewall = false; # we scope the port to wg0 ourselves, below
    settings.WebService = {
      AllowUnencrypted = false; # force HTTPS
      # Adjust to the hostname(s)/VPN name you actually browse to. Cockpit
      # rejects requests whose Origin isn't listed here.
      Origins = "https://heavy6:9090 https://heavy6.wg:9090";
    };
  };

  # cockpit-machines adds the libvirt "Virtual machines" tab; cockpit discovers
  # it from share/cockpit in the system profile.
  environment.systemPackages = [ pkgs.cockpit-machines ];

  # Reachable only from the VPN.
  networking.firewall.interfaces."wg0".allowedTCPPorts = [ 9090 ];

  # TLS: Cockpit auto-generates a self-signed cert at
  # /etc/cockpit/ws-certs.d/. Drop a real cert there (0-self-signed.cert is
  # replaced by any *.cert with a higher prefix) if you want a trusted chain.
}
__NIMOS_EOF__

write modules/vpn.nix <<'__NIMOS_EOF__'
# WireGuard VPN scaffold (wg0). The hypervisor lives on this VPN so Cockpit/SSH
# can be reached from your other nodes without ever exposing them to the LAN.
#
# This is a TEMPLATE: it auto-generates a private key on first boot (no secrets
# needed to come up) and starts wg0 with NO peers, which is harmless. To make it
# useful: set the address/subnet you want, then add peers (see SECURITY.md):
#   - read this host's public key:  wg show wg0 public-key
#   - add each node under `peers` with its publicKey + allowedIPs.
{ ... }:

{
  networking.wireguard.interfaces.wg0 = {
    ips = [ "10.10.0.1/24" ]; # CHANGE to your VPN subnet/address
    listenPort = 51820;

    # Auto-generate and persist a private key at the path below on first boot.
    generatePrivateKeyFile = true;
    privateKeyFile = "/etc/wireguard/wg0.key";

    peers = [
      # {
      #   publicKey = "<peer public key>";
      #   allowedIPs = [ "10.10.0.2/32" ];
      #   # endpoint = "peer.example:51820";   # for outbound/persistent peers
      #   # persistentKeepalive = 25;
      # }
    ];
  };

  # The WireGuard listen port must be reachable on the WAN/LAN to receive
  # handshakes; the tunnelled services (SSH/Cockpit) remain wg0-only.
  networking.firewall.allowedUDPPorts = [ 51820 ];

  # Allow SSH in from the VPN (key-only; see modules/security/hardening.nix).
  networking.firewall.interfaces."wg0".allowedTCPPorts = [ 22 ];
}
__NIMOS_EOF__

write modules/users.nix <<'__NIMOS_EOF__'
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
__NIMOS_EOF__

write modules/vmtweaks.nix <<'__NIMOS_EOF__'
# ./modules/vm-tweaks.nix
{ ... }:
{
  # vmVariant is a function module so that `config`/`pkgs`/`lib` below resolve to
  # the VM's OWN config (where the dev-password sops secret is declared), not the
  # enclosing host config.
  virtualisation.vmVariant =
    { config, pkgs, lib, ... }:
    {


    users.users.dev = {
      isNormalUser = true;
      extraGroups = [ "wheel" ]; # rootless docker needs no "docker" group
      # No plaintext creds in git: hash comes from sops (dev-password secret).
      hashedPasswordFile = config.sops.secrets."dev-password".path;
      linger = true; # keep rootless docker alive without an active login
    };
    users.users.root.hashedPassword = lib.mkForce "!"; # lock root in the dev VM
    sops.secrets."dev-password".neededForUsers = true;

    # This is a LOCAL, NAT'd dev VM reached via `ssh dev@localhost -p 2222`, so
    # re-allow password auth here (the host stays key-only). The forwarded ports
    # also need to be open on the guest firewall now that it's enabled.
    services.openssh.settings.PasswordAuthentication = lib.mkForce true;
    networking.firewall.allowedTCPPorts = [
      22
      8000
      8080
      9090
      3000
      9093
    ];

    
    virtualisation = {
      memorySize = 6144;   # MB. kube-prometheus-stack is hungry; 4096 is tight.
      cores = 4;
      diskSize = 20480;    # MB. kind node image + stack + your images need room.
      graphics = false;    # headless serial console in your terminal

      # host port -> guest port.
      # Guest ports = the ports your `kubectl port-forward` binds INSIDE the VM.
      # IMPORTANT: pass --address 0.0.0.0 to kubectl port-forward so QEMU
      # user-net (10.0.2.15) can reach the binding, not just guest loopback.
      #   kubectl -n <ns> port-forward --address 0.0.0.0 svc/<svc> <port>:<port>
      docker = {
        enable = false; # rootful system daemon OFF
        rootless = {
          enable = true;
          package = pkgs.docker_29;
          setSocketVariable = true; # docker CLI -> rootless socket (sets DOCKER_HOST)
          daemon.settings = {
            dns = [
              "1.1.1.1"
              "8.8.8.8"
            ];
            storage-driver = "overlay2"; # fine on kernel 5.13+; or drop to let it auto-pick
            # registry-mirrors = [ "https://mirror.gcr.io" ];
            # log-driver = "journald";
          };
        };
      };
      forwardPorts = [
        { from = "host"; host.port = 2222; guest.port = 22;   }  # ssh
        { from = "host"; host.port = 8000; guest.port = 8000; }  # app
        { from = "host"; host.port = 8080; guest.port = 8080; }  # app
        { from = "host"; host.port = 9090; guest.port = 9090; }  # prometheus
        { from = "host"; host.port = 3000; guest.port = 3000; }  # grafana
        { from = "host"; host.port = 9093; guest.port = 9093; }  # alertmanager
      ];
    };

    

    environment.systemPackages = with pkgs; [ docker-compose ];

  
  };
}
__NIMOS_EOF__

write disko/luks-ext4.nix <<'__NIMOS_EOF__'
# LUKS2 full-disk-encrypted ext4 layout (reinstall target).
#
# DO NOT wire this into a host that is currently running UNENCRYPTED: the next
# `nixos-rebuild switch` would generate boot.initrd.luks for a device that isn't
# actually encrypted and leave the machine unbootable. In flake.nix this is left
# COMMENTED OUT; swap it in for ./disko/ext4.nix only when you (re)install with
# `disko` (see SECURITY.md).
#
# No on-disk swap partition: a plaintext swap would leak guest RAM. zram swap is
# enabled instead (modules/security/hardening.nix), and hibernation is disabled.
{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/nvme0n1";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "cryptroot";
                settings = {
                  allowDiscards = true; # SSD TRIM (minor metadata leak; acceptable)
                };
                # Passphrase is prompted interactively at install/boot. To script
                # an install, set: passwordFile = "/tmp/secret.key";
                content = {
                  type = "filesystem";
                  format = "ext4";
                  mountpoint = "/";
                };
              };
            };
          };
        };
      };
    };
  };
}
__NIMOS_EOF__

write secrets/secrets.yaml <<'__NIMOS_EOF__'
# ⚠️  PLACEHOLDER — this file MUST be replaced with a sops-ENCRYPTED version
# before you deploy. It exists only so the flake evaluates. The values below are
# NOT secret and NOT used until you encrypt real ones (sops.validateSopsFiles is
# off so this placeholder doesn't fail the build).
#
# To populate real values (see SECURITY.md for the full flow):
#   nix shell nixpkgs#mkpasswd nixpkgs#sops
#   mkpasswd -m yescrypt            # type your password -> copy the $y$... hash
#   sops secrets/secrets.yaml       # paste the hashes, save; sops encrypts at rest
#
# Expected keys (yescrypt password HASHES, never plaintext passwords):
jundmz-password: "REPLACE_ME_with_a_yescrypt_hash"
dev-password: "REPLACE_ME_with_a_yescrypt_hash"
__NIMOS_EOF__

write .sops.yaml <<'__NIMOS_EOF__'
# sops creation rules. Replace the placeholder age recipients with real ones
# before encrypting (see SECURITY.md).
#
# Host key -> age (run on the machine, or against its host pubkey):
#   nix shell nixpkgs#ssh-to-age -c sh -c \
#     'cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age'
# Personal admin key (so YOU can also edit secrets):
#   nix shell nixpkgs#age -c age-keygen -o ~/.config/sops/age/keys.txt
#   # the "public key:" line is your age1... recipient
keys:
  - &host_heavy6 age1REPLACE_with_heavy6_host_age_pubkey
  - &admin age1REPLACE_with_your_admin_age_pubkey

creation_rules:
  - path_regex: secrets/[^/]+\.yaml$
    key_groups:
      - age:
          - *host_heavy6
          - *admin
__NIMOS_EOF__

write SECURITY.md <<'__NIMOS_EOF__'
# Security & Hardening Runbook (`nimos` hypervisor)

This config turns `heavy6` into a **hardened KVM hypervisor**. The design treats
the **host as the trust anchor and guests as hostile**. This file documents the
threat model, the one-time manual steps, the staged rollout order, and how to
verify everything.

## What's configured

| Area | Module | Notes |
|---|---|---|
| Hypervisor (libvirt/QEMU/KVM, OVMF UEFI, swtpm vTPM, virtiofs) | `modules/hypervisor.nix` | QEMU runs as unprivileged `qemu-libvirtd`, seccomp + mount-namespace confined. virt-manager GUI. Default NAT net + storage pool auto-created. |
| Cockpit web UI | `modules/cockpit.nix` | TLS forced, exposed **only on `wg0`** (VPN). `cockpit-machines` for VM mgmt. |
| WireGuard VPN | `modules/vpn.nix` | `wg0` scaffold; auto-generates a key on first boot; add peers. |
| Host hardening | `modules/security/hardening.nix` | nftables default-deny firewall, curated sysctls, hardened boot params, AppArmor, sudo/nix-daemon lockdown, key-only SSH, zram swap (no plaintext swap). |
| Audit | `modules/security/audit.nix` | auditd + libvirt/sudo/ssh/module-load rules. |
| USBGuard | `modules/security/usbguard.nix` | Block unknown USB; keeps already-connected devices. |
| Secrets | `modules/security/secrets.nix` + `secrets/` | sops-nix; **no plaintext credentials in git**. |
| Disk encryption | `disko/luks-ext4.nix` | LUKS2 FDE — reinstall target (see below). |
| Secure Boot | `modules/security/secure-boot.nix` | lanzaboote — staged (see below). |
| Users | `modules/users.nix` | Immutable, sops hashed password, root locked. |

Deliberately **avoided** because they break a hypervisor: `profiles/hardened.nix`,
`linuxPackages_hardened`, disabling user namespaces, blanket `lockKernelModules`,
and `mitigations=off`. See comments in `modules/security/hardening.nix`.

---

## One-time setup (do this BEFORE the first `nixos-rebuild switch`)

### 1. Secrets (required — or the accounts have no password)
Accounts are immutable (`users.mutableUsers = false`) and read their password
hash from sops. If the encrypted secrets file isn't in place, `jundmz` will have
no password.

```sh
nix shell nixpkgs#mkpasswd nixpkgs#sops nixpkgs#ssh-to-age nixpkgs#age

# a) Get heavy6's host age pubkey (run on heavy6, or against its pubkey file):
cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age          # -> age1...

# b) Make a personal admin age key so you can edit secrets too:
age-keygen -o ~/.config/sops/age/keys.txt                   # prints age1...

# c) Put both age1... values into .sops.yaml (host_heavy6 + admin).

# d) Create the encrypted secrets file with the password hashes:
mkpasswd -m yescrypt        # type your password -> copy the $y$... hash
sops secrets/secrets.yaml   # replace placeholders with the real hashes; save
