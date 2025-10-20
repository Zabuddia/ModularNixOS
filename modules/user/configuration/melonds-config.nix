{ config, lib, ... }:

let
  home = config.home.homeDirectory;
  base = "${home}/.local/share/melonDS";
in {
  # Make sure the target dirs exist before melonDS runs
  home.activation.createMelondsDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "${base}/saves" "${base}/states" "${base}/cheats"
  '';

  # Declarative melonDS config
  xdg.configFile."melonDS/melonDS.ini".text = ''
    [Paths]
    SavePath=${base}/saves
    SavestatePath=${base}/states
    CheatPath=${base}/cheats
  '';
}
