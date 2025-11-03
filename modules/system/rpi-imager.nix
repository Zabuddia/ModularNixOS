{ config, unstablePkgs, ... }:

{
  environment.systemPackages = with unstablePkgs; [
    rpi-imager
  ];
}