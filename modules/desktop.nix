{ lib, config, pkgs, hostDesktop, ... }:
let
  d = hostDesktop;
in
lib.mkMerge [
  (lib.mkIf (d == "gnome") {
    services.xserver.enable = true;
    services.xserver.displayManager.gdm.enable = true;
    services.xserver.desktopManager.gnome.enable = true;
  })

  (lib.mkIf (d == "plasma") {
    services.xserver.enable = true;
    services.displayManager.sddm.enable = true;
    services.displayManager.sddm.wayland.enable = true;
    services.desktopManager.plasma6.enable = true;
  })

  (lib.mkIf (d == "cinnamon") {
    services.xserver.enable = true;
    services.xserver.displayManager.lightdm.enable = true;
    services.xserver.desktopManager.cinnamon.enable = true;
  })

  (lib.mkIf (d == "pantheon") {
    services.xserver.enable = true;
    services.xserver.displayManager.lightdm.enable = true;
    services.xserver.desktopManager.pantheon.enable = true;
  })

  (lib.mkIf (d == "headless") {
    services.xserver.enable = lib.mkForce false;
    services.xserver.displayManager.gdm.enable = lib.mkForce false;
    services.displayManager.sddm.enable = lib.mkForce false;
    services.xserver.desktopManager.cinnamon.enable = lib.mkForce false;
    services.xserver.desktopManager.gnome.enable = lib.mkForce false;
    services.desktopManager.plasma6.enable = lib.mkForce false;
    services.xserver.desktopManager.pantheon.enable = lib.mkForce false;
  })
]
