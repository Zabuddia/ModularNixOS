{ ... }: {
  # Pantheon Desktop (Elementary OS style, uses LightDM)
  services.xserver.enable = true;
  services.xserver.displayManager.lightdm.enable = true;
  services.xserver.desktopManager.pantheon.enable = true;
}
