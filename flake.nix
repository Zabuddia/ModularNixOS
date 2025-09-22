{
  description = "Alan's modular NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nixpkgs, home-manager, ... }:
  let
    lib = nixpkgs.lib;

    hostsCfg =
      import ./modules/config/hosts.nix;

    ulistAll =
      if builtins.pathExists ./modules/config/users-list.nix
      then import ./modules/config/users-list.nix
      else throw "Missing modules/config/users-list.nix (copy your example and fill it)";

    mkSystem = host:
      let
        hostName = host.name;

        # Filter users for this host (supports hosts = ["*"] or specific names)
        usersAll = (ulistAll.users or []);
        matchesHost = u:
          let hs = u.hosts or [ "*" ];
          in lib.elem "*" hs || lib.elem hostName hs;

        ulistForHost = { users = builtins.filter matchesHost usersAll; };

        servicesWithDefaults =
          map (s: s // {
            scheme = s.scheme or "http";
            host = s.host or host.name;
          }) (host.services or []);

        serviceModuleFor = svc:
          let path = ./modules/system/services + ("/" + svc.name + ".nix");
          in import path { scheme = svc.scheme; host = svc.host; port = svc.port; };
      in
      nixpkgs.lib.nixosSystem {
        system = host.system;

        specialArgs = {
          inherit inputs hostName;
          ulist = ulistForHost;
          hostDesktop = host.desktop;
          hostPackages = host.systemPackages;
        };

        modules =
          [
            ./modules/base.nix
            ./modules/desktop.nix
            ./modules/avahi.nix
            ./modules/firewall.nix

            home-manager.nixosModules.home-manager

            ./modules/users.nix
            ./modules/hm.nix
            ./modules/host-extras.nix

            { networking.hostName = host.name; }
          ]
          ++ (host.modules or [])
          ++ (map serviceModuleFor servicesWithDefaults);
      };
  in
  {
    nixosConfigurations =
      lib.listToAttrs (map (h: { name = h.name; value = mkSystem h; }) hostsCfg.hosts);
  };
}