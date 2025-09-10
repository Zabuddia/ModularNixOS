{
  hosts = [
    {
      name = "default";
      system = "x86_64-linux";
      desktop = "gnome";
      modules = [
        ../../hosts/default-hardware.nix
      ];
      systemPackages = [
        # Put extra packages here in quotes
      ];
    }
    {
      name = "alan-mba-2013";
      system = "x86_64-linux";
      desktop = "pantheon";
      modules = [
        ../../hosts/alan-mba-2013-hardware.nix
        ../system/dev.nix
        # ../system/tailscale.nix
        ../system/steam.nix
        ../hardware/broadcom-sda.nix
        ../hardware/haswell-gnome-fix.nix
      ];
      systemPackages = [
        # Put extra packages here in quotes
      ];
    }
  ];
}
