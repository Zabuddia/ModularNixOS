{ config, pkgs, ... }:

{
  # Build & load the loopback module for this kernel
  boot.kernelModules = [ "v4l2loopback" ];
  boot.extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];

  # Create a labeled device each boot (shows up as "DroidCam")
  boot.extraModprobeConfig = ''
    options v4l2loopback devices=1 video_nr=10 card_label=DroidCam exclusive_caps=1
  '';

  # Enable DroidCam client binaries
  programs.droidcam.enable = true;
}