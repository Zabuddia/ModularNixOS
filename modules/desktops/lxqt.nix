{ ... }: {
  # LXQt Desktop (lightweight Qt-based, uses SDDM)
  services.xserver.enable = true;
  services.xserver.displayManager.sddm.enable = true;
  services.xserver.desktopManager.lxqt.enable = true;
}
