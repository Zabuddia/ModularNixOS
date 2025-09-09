{ pkgs, ulist, hostDesktop, ... }:
let
  mkHM = u: { pkgs, ... }: {
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
