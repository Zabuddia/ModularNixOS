{
  description = "Alan's modular NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nixpkgs, home-manager, ... }:
  let
    hostsCfg = import ./modules/config/hosts.nix;

    ulist =
      if builtins.pathExists ./modules/config/users-list.nix
      then import ./modules/config/users-list.nix
      else throw "Missing modules/config/users-list.nix (copy your example and fill it)";

    mkSystem = host:
      nixpkgs.lib.nixosSystem {
        system = host.system;
        specialArgs = {
          inherit ulist inputs;
          hostName = host.name;
          hostDesktop = host.desktop;
          hostSpec = host;
        };
        modules =
          [
            ./modules/base.nix
            ./modules/desktop.nix
            home-manager.nixosModules.home-manager
            ./modules/users.nix
            ./modules/hm.nix
            ./modules/host-extras.nix
            { networking.hostName = host.name; }
          ] ++ (host.modules or []);
      };
  in {
    nixosConfigurations =
      nixpkgs.lib.listToAttrs (map (h: { name = h.name; value = mkSystem h; }) hostsCfg.hosts);
  };
}
