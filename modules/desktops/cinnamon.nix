{ ... }: {
  # Cinnamon Desktop (Linux Mint style, uses LightDM)
  services.xserver.enable = true;
  services.xserver.displayManager.lightdm.enable = true;
  services.xserver.desktopManager.cinnamon.enable = true;
}
