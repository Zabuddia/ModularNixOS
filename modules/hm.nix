{ pkgs, ulist, hostDesktop, lib, inputs, ... }:

let
  resolvePkgNames = names:
    map (n:
      if lib.hasAttr n pkgs then builtins.getAttr n pkgs
      else throw "users-list.nix: unknown package name '${n}' (not in pkgs)"
    ) names;

  mkHM = u: { config, pkgs, lib, ... }:
    let
      commonPkgs = with pkgs; [
        htop btop tmux
        tree fastfetch
        ripgrep fd jq
        nmap pavucontrol
        gparted
      ];
      gnomePkgs = with pkgs; [ gnome-tweaks ];
      userExtraPkgs    = resolvePkgNames (u.hm.packages);
      userExtraImports = u.hm.imports;
    in
    {
      home.stateVersion = "25.05";
      programs.home-manager.enable = true;

      # expose 'u' to submodules if needed
      _module.args = { inherit u; };

      # HM writes configs into ~/.config-${hostDesktop}
      xdg = {
        enable = true;
        configHome = "${config.home.homeDirectory}/.config-${hostDesktop}";
      };

      # Export XDG_CONFIG_HOME for apps & user services
      home.sessionVariables.XDG_CONFIG_HOME = config.xdg.configHome;

      home.packages =
        commonPkgs
        ++ (lib.optionals (hostDesktop == "gnome") gnomePkgs)
        ++ userExtraPkgs;

      programs.zsh.enable = (u.shell == "zsh");
      programs.starship.enable = true;
      programs.fzf.enable = true;
      programs.zoxide.enable = true;

      # On login, always nuke & relink ~/.config -> ~/.config-${hostDesktop}
      systemd.user.services."de-config-symlink" = {
        Unit = {
          Description = "Ensure ~/.config points to ~/.config-${hostDesktop}";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          Type = "oneshot";
          ExecStart = pkgs.writeShellScript "de-config-symlink" ''
            set -eu
            tgt="$HOME/.config-${hostDesktop}"
            mkdir -p "$tgt"
            rm -rf "$HOME/.config"
            ln -s "$tgt" "$HOME/.config"
          '';
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };

      imports =
        [ ]
        ++ userExtraImports
        ++ (lib.optionals (hostDesktop == "gnome")  [ u.desktop.gnome ])
        ++ (lib.optionals (hostDesktop == "plasma") [ u.desktop.plasma ]);
    };
in
{
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.backupFileExtension = "backup";

  home-manager.users =
    builtins.listToAttrs (map (u: { name = u.name; value = mkHM u; }) ulist.users);
}