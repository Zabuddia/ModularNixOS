{ config, pkgs, ... }:

{
  programs.kodi = {
    enable = true;
    package = pkgs.kodi-wayland;

    sources = {
      video = [
        {
          name = "Invidious";
          path = "https://youtube.zabuddia.org";
        }
      ];
    };
  };
}
