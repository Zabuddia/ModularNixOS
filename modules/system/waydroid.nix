{ config, pkgs, ... }:
{
  virtualisation.waydroid.enable = true;
  virtualisation.lxc.enable = true;
  hardware.graphics.enable = true;
  environment.systemPackages = [ pkgs.waydroid ];
}