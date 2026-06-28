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
