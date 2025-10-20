{ config, lib, pkgs, ... }:

let
  home = config.home.homeDirectory;
  base = "${home}/.local/share/melonDS";
in {
  # Ensure the directories exist
  home.activation.createMelondsDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "${base}/saves" "${base}/states" "${base}/cheats"
  '';

  # Declarative config for melonDS
  xdg.configFile."melonDS/melonDS.ini".text = ''
    [Paths]
    SavePath=${base}/saves
    SavestatePath=${base}/states
    CheatPath=${base}/cheats
  '';

  home.packages = [ pkgs.melonDS ];
}