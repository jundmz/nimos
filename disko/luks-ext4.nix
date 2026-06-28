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
