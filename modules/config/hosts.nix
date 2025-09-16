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
      desktop = "gnome";
      modules = [
        ../../hosts/alan-mba-2013-hardware.nix
        ../system/dev.nix
        ../system/tailscale.nix
        ../system/steam.nix
        ../system/waydroid.nix
        ../system/vm.nix
        ../system/tor.nix
        ../system/flatpak.nix
        (import ../system/auto-login.nix { user = "buddia"; })
        ../hardware/hp-printer.nix
        ../hardware/broadcom-sda.nix
        ../hardware/haswell-gnome-fix.nix
        ../hardware/all-firmware.nix
      ];
      systemPackages = [
        "rpi-imager"
      ];
    }
    {
      name = "alan-laptop-nixos";
      system = "x86_64-linux";
      desktop = "gnome";
      modules = [
        ../../hosts/alan-laptop-nixos-hardware.nix
        ../system/dev.nix
        ../system/tailscale.nix
        ../system/steam.nix
        ../system/waydroid.nix
        ../system/tor.nix
        ../system/flatpak.nix
        ../system/vm.nix
        ../system/wireshark.nix
        ../hardware/hp-printer.nix
        ../hardware/all-firmware.nix
      ];
      systemPackages = [
        "rpi-imager"
      ];
    }
  ];
}
