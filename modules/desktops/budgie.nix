{ ... }: {
  # Budgie Desktop (best with GDM)
  services.xserver.enable = true;
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.budgie.enable = true;
}
