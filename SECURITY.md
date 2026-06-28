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
