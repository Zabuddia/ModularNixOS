{
  hosts = [
    rec {
      name = "alan-mba-2013";
      system = "x86_64-linux";
      desktop = "gnome";
      services = [
        { name = "gitea"; port = 3000; expose = "caddy"; scheme = "https"; domain = "alan-mba-2013"; }
        { name = "pyhttp"; port = 3001; expose = "caddy"; scheme = "https"; domain = "alan-mba-2013"; }
        { name = "invidious"; port = 3002; expose = "tailscale"; scheme = "https"; domain = "alan-mba-2013"; }
      ];
      modules = [
        ../../hosts/alan-mba-2013-hardware.nix
        ../system/ssh.nix
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
    rec {
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
    rec {
      name = "alan-big-nixos";
      system = "x86_64-linux";
      desktop = "gnome";
      services = [
        { name = "gitea"; port = 3000; expose = "tailscale"; scheme = "https"; domain = "alan-big-nixos.tailbb2802.ts.net"; }
        { name = "pyhttp"; port = 3001; expose = "tailscale"; scheme = "https"; domain = "alan-big-nixos.tailbb2802.ts.net"; }
        { name = "guacamole"; port = 3002; expose = "tailscale"; scheme = "https"; domain = "alan-big-nixos.tailbb2802.ts.net"; }
        { name = "nextcloud"; port = 3003; expose = "tailscale"; scheme = "https"; domain = "alan-big-nixos.tailbb2802.ts.net"; }
        { name = "yt-api"; port = 3004; expose = "tailscale"; scheme = "https"; domain = "alan-big-nixos.tailbb2802.ts.net"; }
        { name = "tv-controller"; port = 3005; streamPort = 1234; expose = "tailscale"; scheme = "https"; domain = "alan-big-nixos.tailbb2802.ts.net"; }
        { name = "invidious"; port = 3006; expose = "tailscale"; scheme = "https"; domain = "alan-big-nixos.tailbb2802.ts.net"; }
        { name = "n8n"; port = 3007; expose = "tailscale"; scheme = "https"; domain = "alan-big-nixos.tailbb2802.ts.net"; }
      ];
      modules = [
        ../../hosts/alan-big-nixos-hardware.nix
        ../system/ssh.nix
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
