{ pkgs, ... }:
{
  home.packages = [ pkgs.melonDS ];
  imports = [ ./configuration/melonds-config.nix ];
}