{ pkgs, ulist, hostDesktop, lib, inputs, ... }:

let
  hmDag = inputs.home-manager.lib.hm.dag;

  resolvePkgNames = names:
    map (n:
      if lib.hasAttr n pkgs then builtins.getAttr n pkgs
      else throw "users-list.nix: unknown package name '${n}' (not in pkgs)"
    ) names;

  mkHM = u:
    let
      commonPkgs = with pkgs; [
        htop btop tmux
        tree fastfetch
        ripgrep fd jq
        nmap pavucontrol
        gparted
      ];

      gnomePkgs = with pkgs; [
        gnome-tweaks
        extension-manager
        dconf-cli
      ];

      userExtraPkgs = resolvePkgNames (u.hm.packages or []);
      userExtraImports = (u.hm.imports or []);
    in {
      home.stateVersion = "25.05";
      programs.home-manager.enable = true;
      
      # Allows all imports to inherit u
      _module.args = { inherit u; };

      home.packages =
        commonPkgs ++ (lib.optionals (hostDesktop == "gnome") gnomePkgs);

      # shells / QoL
      programs.zsh.enable = (u.shell == "zsh");
      programs.starship.enable = true;
      programs.fzf.enable = true;
      programs.zoxide.enable = true;

      home.activation.deSwitch = hmDag.entryBefore [ "writeBoundary" ] ''
        set -eu
        # 1) Per-DE ~/.config via symlink
        rm -rf "$HOME/.config"
        mkdir -p "$HOME/.config-${hostDesktop}"
        ln -sfn "$HOME/.config-${hostDesktop}" "$HOME/.config"

        # 2) Fresh cache every switch
        rm -rf "$HOME/.cache"
        mkdir -p "$HOME/.cache"
      '';

      imports = [
        
      ]
      ++ userExtraImports
      ++ (lib.optionals (hostDesktop == "gnome") [ u.desktop.gnome ])
      ++ (lib.optionals (hostDesktop == "plasma") [ u.desktop.plasma ]);
    };
in {
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users =
    builtins.listToAttrs (map (u: { name = u.name; value = mkHM u; }) ulist.users);
}
