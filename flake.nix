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
            # ./modules/vmtweaks.nix
            # ./modules/virtualization.nix

            # Security hardening (host = trust anchor, guests = hostile)
            # ./modules/security/secrets.nix
            ./modules/security/hardening.nix
            ./modules/security/audit.nix
            ./modules/security/usbguard.nix
            # ./modules/security/secure-boot.nix   # enable AFTER sbctl key enrollment

            # Hypervisor stack + management surfaces
            (import ./modules/hypervisor.nix "jundmz")
            # ./modules/cockpit.nix
            # ./modules/vpn.nix

            (import ./modules/users.nix "jundmz")
            # inputs.niri-flake.nixosModules.niri   # niri pkg + xdg-portal-gnome
          ]
          ++ mkHome "jundmz" ./home;
        };

        dvm = mkHost {
          system = "x86_64-linux";
          modules = [
            # "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
            ./modules/core.nix
            ./modules/keyd.nix
            # ./modules/physical.nix
            # ./modules/vmtweaks.nix
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
