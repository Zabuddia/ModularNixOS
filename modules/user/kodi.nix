{ config, pkgs, lib, ... }:

{
  programs.kodi = {
    enable = true;
    # Build addons against kodi-wayland
    package = pkgs.kodi-wayland.withPackages (kp: [
      kp.inputstream-adaptive
      kp.invidious
      kp.jellyfin
      kp.pvr-iptvsimple
      kp.pvr-hts
      # kp.libretro-2048  # add more if you want
    ]);

  };
}