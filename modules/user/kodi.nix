{ config, pkgs, ... }:

{
  programs.kodi = {
    enable = true;
    package = pkgs.kodi-wayland;
  };

  home.packages = with pkgs.kodiPackages; [
    inputstream-adaptive
    invidious
  ];
}