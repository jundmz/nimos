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
