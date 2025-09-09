{ pkgs, ulist, hostDesktop, ... }:
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

    # --- per-DE config/cache handling ---
    # Pivot ~/.config -> ~/.config-${hostDesktop} and clear ~/.cache
    # Do this BEFORE HM writes files so they land in the per-DE tree.
    home.activation.deSwitch = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
      set -eu

      # 1) Per-DE .config via symlink (no backups)
      rm -rf "$HOME/.config"
      mkdir -p "$HOME/.config-${hostDesktop}"
      ln -sfn "$HOME/.config-${hostDesktop}" "$HOME/.config"

      # 2) Fresh cache every switch
      rm -rf "$HOME/.cache"
      mkdir -p "$HOME/.cache"
    '';

    # one-liners per DE:
    dconf.settings =
      if hostDesktop == "gnome" then u.desktop.gnome.dconf
      else {};

    xdg.configFile =
      if hostDesktop == "plasma" then u.desktop.plasma.xdgConfigFile
      else {};
  };
in {
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users =
    builtins.listToAttrs (map (u: { name = u.name; value = mkHM u; }) ulist.users);
}
