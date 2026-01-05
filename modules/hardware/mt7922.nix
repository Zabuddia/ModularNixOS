{ config, lib, pkgs, ... }:

{
  hardware.enableRedistributableFirmware = true;

  hardware.wirelessRegulatoryDatabase = true;

  boot.kernelModules = [ "mt7921e" ];

  networking.networkmanager.enable = true;
  networking.wireless.enable = false;
}
