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
      ];

      userExtraPkgs = resolvePkgNames (u.hm.packages);
      userExtraImports = (u.hm.imports);
    in {
      home.stateVersion = "25.05";
      programs.home-manager.enable = true;

      # Allows all imports to inherit u
      _module.args = { inherit u; };

      home.packages =
        commonPkgs
        ++ (lib.optionals (hostDesktop == "gnome") gnomePkgs)
        ++ userExtraPkgs;

      # shells / QoL
      programs.zsh.enable = (u.shell == "zsh");
      programs.starship.enable = true;
      programs.fzf.enable = true;
      programs.zoxide.enable = true;

      # --- Per-DE XDG config (absolute path, no `config.*`) ---
      home.activation.deSwitch = hmDag.entryBefore [ "writeBoundary" ] ''
        set -eu
        rm -rf "$HOME/.config"
        mkdir -p "$HOME/.config-${hostDesktop}"
        ln -sfn "$HOME/.config-${hostDesktop}" "$HOME/.config"

        rm -rf "$HOME/.cache"
        mkdir -p "$HOME/.cache"
      '';

      imports =
        [ ]
        ++ userExtraImports
        ++ (lib.optionals (hostDesktop == "gnome") [ u.desktop.gnome ])
        ++ (lib.optionals (hostDesktop == "plasma") [ u.desktop.plasma ]);
    };
in {
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.backupFileExtension = "backup";
  home-manager.users =
    builtins.listToAttrs (map (u: { name = u.name; value = mkHM u; }) ulist.users);
}
