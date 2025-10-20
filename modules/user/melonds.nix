{ pkgs, ... }:
{
  home.packages = [ pkgs.melonds ];
  imports = [ ../configuration/melonds-config.nix ];
}