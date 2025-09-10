{
  hosts = [
    {
      name = "default";
      system = "x86_64-linux";
      desktop = "gnome";
      modules = [
        ../../hosts/default-hardware.nix
      ];
    }
    {
      name = "alan-mba-2013";
      system = "x86_64-linux";
      desktop = "pantheon";
      modules = [
        ../../hosts/alan-mba-2013-hardware.nix
        ../dev.nix
        ../hardware/broadcom-sda.nix
        ../hardware/haswell-gnome-fix.nix
      ];
    }
  ];
}
