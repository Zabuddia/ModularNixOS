{ pkgs, ... }:
{
  programs.distrobox = {
    enable = true;
    package = pkgs.distrobox;
  };
}