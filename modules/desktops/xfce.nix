{ ... }:
{
  # XFCE (lightweight) with LightDM
  services.xserver.enable = true;
  services.xserver.displayManager.lightdm.enable = true;
  services.xserver.desktopManager.xfce.enable = true;
}
