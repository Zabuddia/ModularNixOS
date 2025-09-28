{
  description = "Alan's modular NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
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

        svcDefsLocal = host.services or [];

        # Conditionally include expose module (it also imports backend service modules)
        exposeModule =
          if builtins.length svcDefsLocal > 0 then
            (import ./modules/system/expose-services.nix {
              svcDefs = svcDefsLocal;
            })
          else
            null;
      in
      nixpkgs.lib.nixosSystem {
        system = host.system;

        specialArgs = {
          inherit inputs hostName;
          ulist = ulistForHost;
          hostDesktop = host.desktop;
          hostPackages = host.systemPackages;
          unstablePkgs = inputs.nixpkgs-unstable.legacyPackages.${host.system};
        };

        modules =
          [
            ./modules/base.nix
            ./modules/desktop.nix
            ./modules/avahi.nix
            ./modules/firewall.nix

            home-manager.nixosModules.home-manager

            # Make the unstable pkgs set available to the HM modules
            {
              home-manager.extraSpecialArgs = {
                unstablePkgs = inputs.nixpkgs-unstable.legacyPackages.${host.system};
              };
            }

            ./modules/users.nix
            ./modules/hm.nix
            ./modules/host-extras.nix

            { networking.hostName = host.name; }
          ]
          ++ (host.modules or [])
          # expose module (does backends + exposure) only when services are present
          ++ lib.optional (exposeModule != null) exposeModule;
      };
  in
  {
    nixosConfigurations =
      lib.listToAttrs (map (h: { name = h.name; value = mkSystem h; }) hostsCfg.hosts);
  };
}