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
