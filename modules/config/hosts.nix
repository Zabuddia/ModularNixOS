{
  hosts = [
    rec {
      name = "alan-mba-2013";
      system = "x86_64-linux";
      timezone = "America/Denver";
      desktop = "gnome";
      services = [
        { name = "gitea"; port = 3000; expose = "caddy-lan"; scheme = "https"; domain = "alan-mba-2013"; }
        { name = "pyhttp"; port = 3001; expose = "caddy-lan"; scheme = "https"; domain = "alan-mba-2013"; }
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
      timezone = "America/Denver";
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
      timezone = "America/Denver";
      desktop = "gnome";
      services = [
        { name = "dashboard"; port = 3000; expose = "tailscale"; scheme = "https"; domain = "alan-big-nixos.tailbb2802.ts.net"; }
        { name = "gitea"; port = 3001; expose = "tailscale"; scheme = "https"; domain = "alan-big-nixos.tailbb2802.ts.net"; }
        { name = "pyhttp"; port = 3002; expose = "tailscale"; scheme = "https"; domain = "alan-big-nixos.tailbb2802.ts.net"; }
        { name = "guacamole"; port = 3003; expose = "tailscale"; scheme = "https"; domain = "alan-big-nixos.tailbb2802.ts.net"; }
        { name = "nextcloud"; port = 3004; expose = "tailscale"; scheme = "https"; domain = "alan-big-nixos.tailbb2802.ts.net"; }
        { name = "yt-api"; port = 3005; expose = "tailscale"; scheme = "https"; domain = "alan-big-nixos.tailbb2802.ts.net"; }
        { name = "tv-controller"; port = 3006; streamPort = 1234; expose = "tailscale"; scheme = "https"; domain = "alan-big-nixos.tailbb2802.ts.net"; }
        { name = "invidious"; port = 3007; expose = "tailscale"; scheme = "https"; domain = "alan-big-nixos.tailbb2802.ts.net"; }
        { name = "n8n"; port = 3008; expose = "tailscale"; scheme = "https"; domain = "alan-big-nixos.tailbb2802.ts.net"; }
        { name = "ollama"; port = 3009; expose = "tailscale"; scheme = "https"; domain = "alan-big-nixos.tailbb2802.ts.net"; }
      ];
      nextcloudUsers = [
        {
          name         = "buddia";
          displayName  = "Alan Fife";
          email        = "fife.alan@protonmail.com";
          isAdmin      = true;
        }
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
    rec {
      name = "nixos-home";
      system = "x86_64-linux";
      timezone = "America/Denver";
      desktop = "gnome";
      services = [
        { name = "dashboard"; port = 3000; expose = "caddy-wan"; scheme = "https"; domain = "www.zabuddia.org"; }
        { name = "gitea"; port = 3001; expose = "caddy-wan"; scheme = "https"; domain = "git.zabuddia.org"; }
        { name = "guacamole"; port = 3002; expose = "caddy-wan"; scheme = "https"; domain = "guacamole.zabuddia.org"; }
        { name = "nextcloud"; port = 3003; expose = "caddy-wan"; scheme = "https"; domain = "nextcloud.zabuddia.org"; }
        { name = "tv-controller"; port = 3004; streamPort = 1234; expose = "caddy-wan"; scheme = "https"; domain = "tv.zabuddia.org"; }
        { name = "invidious"; port = 3005; expose = "caddy-wan"; scheme = "https"; domain = "youtube.zabuddia.org"; }
        { name = "n8n"; port = 3006; expose = "caddy-wan"; scheme = "https"; domain = "n8n.zabuddia.org"; }
        { name = "ollama"; port = 3007; expose = "caddy-wan"; scheme = "https"; domain = "llm.zabuddia.org"; }
      ];
      nextcloudUsers = [
        {
          name         = "buddia";
          displayName  = "Alan Fife";
          email        = "fife.alan@protonmail.com";
          isAdmin      = true;
        }
        {
          name         = "waffleiron";
          displayName  = "Randy Fife";
          email        = "fife.randy@protonmail.com";
          isAdmin      = true;
        }
        {
          name         = "fifefam";
          displayName  = "Family Account";
          email        = "fifefam@gmail.com";
          isAdmin      = false;
        }
      ];
      modules = [
        ../../hosts/nixos-home-hardware.nix
        ../system/ddclient.nix
        ../system/ssh.nix
        ../system/dev.nix
        ../system/tailscale.nix
        ../system/waydroid.nix
        ../system/tor.nix
        ../system/flatpak.nix
        ../system/vm.nix
        ../system/fix-codium-server.nix
        ../system/remote-desktop.nix
        ../system/sunshine.nix
        ../hardware/all-firmware.nix
      ];
      systemPackages = [
        "rpi-imager"
      ];
    }
  ];
}
