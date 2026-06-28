
keys

ports

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
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

## Module layout (new + modified)

### New modules
| File | Purpose | Applied to |
|---|---|---|
| `modules/security/hardening.nix` | Kernel sysctls, boot params, AppArmor, sudo, nix-daemon hardening, firewall base, login | **both** hosts |
| `modules/security/audit.nix` | `auditd` + audit ruleset | both |
| `modules/security/usbguard.nix` | USBGuard block-by-default + allowlist guidance | `heavy6` |
| `modules/security/secrets.nix` | sops-nix wiring (age key, default secrets file) | both |
| `modules/security/secure-boot.nix` | lanzaboote (staged enable) | `heavy6` |
| `modules/hypervisor.nix` | libvirtd/QEMU/KVM/OVMF/swtpm/virtiofsd, virt-manager, storage pool, network, sVirt knobs | `heavy6` |
| `modules/cockpit.nix` | Cockpit + cockpit-machines, TLS, VPN-interface-only firewall | `heavy6` |
| `modules/vpn.nix` | WireGuard scaffold (`wg0`) so Cockpit/SSH bind to the VPN | `heavy6` (template) |
| `disko/luks-ext4.nix` | LUKS2 + ext4 layout (reinstall target) | `heavy6` (opt-in) |

### Modified files
- `flake.nix` — add inputs `sops-nix`, `lanzaboote`; wire new modules; change
  `virtualization`/`hypervisor` import to the `import ./modules/x.nix "jundmz"`
  username pattern already used by `users.nix:3`.
- `modules/users.nix` — `mutableUsers=false`, `hashedPasswordFile` from sops, add
  `libvirtd`/`kvm` groups, drop the plaintext `initialPassword`.
- `modules/vmtweaks.nix` — remove committed `"dev"`/`"root"` plaintext passwords
  (sops `hashedPasswordFile`, and lock root via `hashedPassword = "!"`).
- `modules/core.nix` — move/centralize nothing destructive; just import nits + keep.


