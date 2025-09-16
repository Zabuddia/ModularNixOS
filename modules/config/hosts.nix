{
  hosts = [
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
        ../system/auto-login.nix
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
    {
      name = "alan-big-nixos";
      system = "x86_64-linux";
      desktop = "gnome";
      modules = [
        ../../hosts/alan-big-nixos-hardware.nix
        ../system/dev.nix
        ../system/tailscale.nix
        ../system/steam.nix
        ../system/waydroid.nix
        ../system/tor.nix
        ../system/flatpak.nix
        ../system/vm.nix
        ../system/auto-login.nix
        ../system/fix-codium-server.nix
        ../system/services/gitea.nix
        ../hardware/hp-printer.nix
        ../hardware/all-firmware.nix
      ];
      systemPackages = [
        "rpi-imager"
      ];
    }
  ];
}
