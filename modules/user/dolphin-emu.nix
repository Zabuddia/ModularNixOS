{ config, pkgs, ... }:
{
  home.packages = [ pkgs.dolphin-emu ];
  imports = [ configuration/dolphin-emu-config.nix ];
}