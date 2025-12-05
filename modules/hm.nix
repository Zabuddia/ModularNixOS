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
        powertop
      ];

      gnomePkgs = with pkgs; [
        gnome-tweaks
        gnome-software
        gnome-usage
        gnome-power-manager
      ];

      userExtraPkgs    = resolvePkgNames (u.hm.packages);
      userExtraImports = u.hm.imports;

      # Hard-wire hostDesktop; robust relinker for login sessions
      relinkBin = pkgs.writeShellScriptBin "de-config-relink" ''
        set -euo pipefail
        RSYNC='${pkgs.rsync}/bin/rsync'
        FIND='${pkgs.findutils}/bin/find'
        LN='${pkgs.coreutils}/bin/ln'
        RMDIR='${pkgs.coreutils}/bin/rmdir'
        MKDIR='${pkgs.coreutils}/bin/mkdir'

        desk='${hostDesktop}'
        tgt="$HOME/.config-$desk"
        "$MKDIR" -p "$tgt"

        if [ -L "$HOME/.config" ]; then
          "$LN" -sfn "$tgt" "$HOME/.config"
        elif [ -d "$HOME/.config" ]; then
          "$RSYNC" -a --remove-source-files "$HOME/.config"/ "$tgt"/ || true
          "$FIND" "$HOME/.config" -type d -empty -delete || true
          "$RMDIR" "$HOME/.config" 2>/dev/null || true
          "$LN" -sfn "$tgt" "$HOME/.config"
        else
          "$LN" -sfn "$tgt" "$HOME/.config"
        fi
      '';
    in
    {
      home.stateVersion = "25.11";
      programs.home-manager.enable = true;

      # expose 'u' to submodules if needed
      _module.args = { inherit u; };

      # Packages
      home.packages =
        commonPkgs
        ++ (lib.optionals (hostDesktop == "gnome") gnomePkgs)
        ++ userExtraPkgs;

      # QoL
      programs.zsh.enable = (u.shell == "zsh");
      programs.starship.enable = true;
      programs.fzf.enable = true;
      programs.zoxide.enable = true;

      ########################################################################
      # 1) Do it NOW at HM switch time (pre-write) to avoid first-login races
      ########################################################################
      home.activation.deConfigPrepare = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
        set -euo pipefail
        RSYNC='${pkgs.rsync}/bin/rsync'
        FIND='${pkgs.findutils}/bin/find'
        LN='${pkgs.coreutils}/bin/ln'
        RMDIR='${pkgs.coreutils}/bin/rmdir'
        MKDIR='${pkgs.coreutils}/bin/mkdir'

        desk='${hostDesktop}'
        tgt="$HOME/.config-$desk"
        "$MKDIR" -p "$tgt"

        if [ -L "$HOME/.config" ]; then
          "$LN" -sfn "$tgt" "$HOME/.config"
        elif [ -d "$HOME/.config" ]; then
          "$RSYNC" -a --remove-source-files "$HOME/.config"/ "$tgt"/ || true
          "$FIND" "$HOME/.config" -type d -empty -delete || true
          "$RMDIR" "$HOME/.config" 2>/dev/null || true
          "$LN" -sfn "$tgt" "$HOME/.config"
        else
          "$LN" -sfn "$tgt" "$HOME/.config"
        fi
      '';

      ########################################################################
      # 2) Also enforce on every graphical login, *before* DE autostarts
      ########################################################################
      systemd.user.services.de-config-relink = {
        Unit = {
          Description = "Relink ~/.config to per-DE dir (${hostDesktop})";
          # Run as early as possible in the user graphical session
          Wants = [ "graphical-session-pre.target" ];
          After = "graphical-session-pre.target";
          # Try to beat XDG autostarts too (generator-created target)
          Before = [ "xdg-desktop-autostart.target" "graphical-session.target" ];
          PartOf = "graphical-session.target";
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${relinkBin}/bin/de-config-relink";
        };
        Install = {
          WantedBy = [ "graphical-session.target" ];
        };
      };

      ########################################################################
      # Optional: per-DE imports
      ########################################################################
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
