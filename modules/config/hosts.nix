{
  hosts = [
    {
      name = "alan-mba-2013";
      system = "x86_64-linux";
      desktop = "gnome";
      services = [
        { name = "gitea"; scheme = "http"; domain = "alan-mba-2013"; port = 3000; }
        { name = "invidious"; scheme = "http"; domain = "alan-mba-2013"; port = 3001; }
      ];
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
        ../system/remote-desktop.nix
        ../system/sunshine.nix
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
      services = [ ];
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
        ../system/remote-desktop.nix
        ../system/sunshine.nix
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
      services = [
        { name = "gitea"; scheme = "http"; domain = "alan-big-nixos"; port = 3000; }
        { name = "invidious"; scheme = "http"; domain = "alan-big-nixos"; port = 3001; }
        { name = "n8n"; scheme = "http"; domain = "alan-big-nixos"; port = 5678; }
      ];
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
        ../system/remote-desktop.nix
        ../system/sunshine.nix
        ../hardware/hp-printer.nix
        ../hardware/all-firmware.nix
      ];
      systemPackages = [
        "rpi-imager"
      ];
    }
  ];
}
