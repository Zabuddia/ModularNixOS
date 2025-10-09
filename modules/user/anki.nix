{ pkgs, ... }:

{
  programs.anki = {
    enable = true;
    package = pkgs.anki;

    # optional nice defaults
    theme = "auto";
    minimalistMode = true;
    uiScale = 1.0;
  };
}