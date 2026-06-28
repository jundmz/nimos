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
