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
