{ ... }: {
  # MATE Desktop (GNOME 2 fork, uses LightDM)
  services.xserver.enable = true;
  services.xserver.displayManager.lightdm.enable = true;
  services.xserver.desktopManager.mate.enable = true;
}
