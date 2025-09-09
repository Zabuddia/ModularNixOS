{ lib, config, pkgs, hostDesktop, ... }:
let
  d = hostDesktop;

  # Optional presets (empty set if not selected)
  gnomePreset =
    if d == "gnome-minimal"
    then import ./desktops/gnome/minimal.nix { inherit pkgs; }
    else {};

  plasmaPreset =
    if d == "plasma-minimal"
    then import ./desktops/plasma/minimal.nix { inherit pkgs; }
    else {};
in
lib.mkMerge [
  # GNOME (full + minimal both enable GNOME)
  (lib.mkIf (d == "gnome" || d == "gnome-minimal") {
    services.xserver.enable = true;
    services.xserver.displayManager.gdm.enable = true;
    services.xserver.desktopManager.gnome.enable = true;
  })
  gnomePreset

  # Plasma (full + minimal both enable Plasma 6)
  (lib.mkIf (d == "plasma" || d == "plasma-minimal") {
    services.xserver.enable = true;
    services.displayManager.sddm.enable = true;
    services.displayManager.sddm.wayland.enable = true;
    services.desktopManager.plasma6.enable = true;
  })
  plasmaPreset

  # Cinnamon
  (lib.mkIf (d == "cinnamon") {
    services.xserver.enable = true;
    services.xserver.displayManager.lightdm.enable = true;
    services.xserver.desktopManager.cinnamon.enable = true;
  })

  # Pantheon
  (lib.mkIf (d == "pantheon") {
    services.xserver.enable = true;
    services.xserver.displayManager.lightdm.enable = true;
    services.xserver.desktopManager.pantheon.enable = true;
  })

  # Headless
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
