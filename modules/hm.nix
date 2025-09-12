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
      gnomePkgs = with pkgs; [
        gnome-tweaks
        gnome-software
      ];
      userExtraPkgs    = resolvePkgNames (u.hm.packages);
      userExtraImports = u.hm.imports;

      relinkBin = pkgs.writeShellScriptBin "de-config-relink" ''
        #!/usr/bin/env bash
        set -eu

        # Determine current desktop environment without parameter-expansion syntax
        raw="$(printenv XDG_CURRENT_DESKTOP || true)"
        if [ -z "$raw" ]; then
          raw="$(printenv DESKTOP_SESSION || true)"
        fi
        if [ -z "$raw" ]; then
          raw="unknown"
        fi

        low="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]')"

        case "$low" in
          *kde*|*plasma*) desk="plasma" ;;
          *gnome*)        desk="gnome"  ;;
          *cinnamon*)     desk="cinnamon" ;;
          *pantheon*)     desk="pantheon" ;;
          *xfce*)         desk="xfce" ;;
          *)              desk="default" ;;
        esac

        tgt="$HOME/.config-$desk"
        mkdir -p "$tgt"

        # Always relink on login
        rm -rf "$HOME/.config"
        ln -s "$tgt" "$HOME/.config"
      '';
    in
    {
      home.stateVersion = "25.05";
      programs.home-manager.enable = true;

      # expose 'u' to submodules if needed
      _module.args = { inherit u; };

      home.packages =
        commonPkgs
        ++ (lib.optionals (hostDesktop == "gnome") gnomePkgs)
        ++ userExtraPkgs;

      programs.zsh.enable = (u.shell == "zsh");
      programs.starship.enable = true;
      programs.fzf.enable = true;
      programs.zoxide.enable = true;

      # Relink ~/.config on EVERY LOGIN (graphical sessions) via XDG autostart
      xdg.autostart.enable = true;
      xdg.desktopEntries.de-config-relink = {
        name = "Per-DE config relink";
        exec = "${relinkBin}/bin/de-config-relink";
        terminal = false;
        noDisplay = true;
        categories = [ "Utility" ];
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