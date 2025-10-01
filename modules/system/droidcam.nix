{ config, pkgs, ... }:

{
  programs.droidcam.enable = true;

  boot.kernelModules = [ "v4l2loopback" ];
  boot.extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];

  environment.systemPackages = with pkgs; [
    ffmpeg
    v4l-utils
  ];
}