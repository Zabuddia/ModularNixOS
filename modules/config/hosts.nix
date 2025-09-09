{
  hosts = [
    {
      name = "default";
      system = "x86_64-linux";
      desktop = "gnome";
      hardwareModules = [
        ../../hosts/default-hardware.nix
      ];
    }
    {
      name = "alan-mba-2013";
      system = "x86_64-linux";
      desktop = "gnome-minimal";
      hardwareModules = [
        ../../hosts/alan-mba-2013-hardware.nix
        ../hardware/broadcom-sda.nix
        ../hardware/haswell-gnome-fix.nix
      ];
    }
  ];
}
