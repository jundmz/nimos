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
