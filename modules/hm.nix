{ pkgs, ulist, hostDesktop, lib, ... }:
let
  mkHM = u: { pkgs, lib, ... }: {
    home.stateVersion = "25.05";
    programs.home-manager.enable = true;

    home.packages = with pkgs; [ ];
    programs.zsh.enable = (u.shell == "zsh");

    programs.git = {
      enable = true;
      userName  = u.fullName;
      userEmail = u.email;
      extraConfig.init.defaultBranch = "main";
    };
    programs.firefox.enable = true;

    home.activation.deSwitch = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
      set -eu

      # 1) Per-DE ~/.config via symlink
      rm -rf "$HOME/.config"
      mkdir -p "$HOME/.config-${hostDesktop}"
      ln -sfn "$HOME/.config-${hostDesktop}" "$HOME/.config"

      # 2) Fresh cache every switch
      rm -rf "$HOME/.cache"
      mkdir -p "$HOME/.cache"
    '';

    imports =
      (lib.optionals (hostDesktop == "gnome") [ u.desktop.gnome ])
      ++ (lib.optionals (hostDesktop == "plasma") [ u.desktop.plasma ]);
  };
in {
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users =
    builtins.listToAttrs (map (u: { name = u.name; value = mkHM u; }) ulist.users);
}
