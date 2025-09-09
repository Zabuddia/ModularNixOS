{ ... }: {
  # Enlightenment Desktop (uses LightDM)
  services.xserver.enable = true;
  services.xserver.displayManager.lightdm.enable = true;
  services.xserver.desktopManager.enlightenment.enable = true;
}
