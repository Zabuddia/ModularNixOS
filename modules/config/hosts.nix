{
  hosts = [
    rec {
      name = "alan-mba-2013";
      system = "x86_64-linux";
      timezone = "America/Denver";
      desktop = "gnome";
      services = [ ];
      modules = [
        ../../hosts/alan-mba-2013-hardware.nix
        ../system/ssh.nix
        ../system/dev.nix
        ../system/tailscale.nix
        ../system/steam.nix
        ../system/waydroid.nix
        ../system/tor.nix
        ../system/flatpak.nix
        ../system/remote-desktop.nix
        ../system/sunshine.nix
        ../system/uxplay.nix
        ../hardware/hp-printer.nix
        ../hardware/broadcom-sda.nix
        ../hardware/haswell-gnome-fix.nix
        ../hardware/all-firmware.nix
      ];
      systemPackages = [ ];
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
        ../system/rpi-imager.nix
        ../system/vm.nix
        ../system/wireshark.nix
        ../system/remote-desktop.nix
        ../system/sunshine.nix
        ../system/droidcam.nix
        ../system/podman.nix
        ../system/uxplay.nix
        ../hardware/hp-printer.nix
        ../hardware/all-firmware.nix
      ];
      systemPackages = [ ];
    }
    rec {
      name = "alan-big-nixos";
      system = "x86_64-linux";
      timezone = "America/Denver";
      desktop = "gnome";
      services = [
        { name = "dashboard"; port = 3010; expose = "tailscale"; scheme = "https"; domain = "alan-big-nixos.tailbb2802.ts.net"; }
        # { name = "gitea"; port = 3011; expose = "tailscale"; scheme = "https"; domain = "alan-big-nixos.tailbb2802.ts.net"; }
        { name = "pyhttp"; port = 3012; expose = "tailscale"; scheme = "https"; domain = "alan-big-nixos.tailbb2802.ts.net"; }
        { name = "guacamole"; port = 3013; expose = "tailscale"; scheme = "https"; domain = "alan-big-nixos.tailbb2802.ts.net"; }
        # { name = "nextcloud"; port = 3014; expose = "tailscale"; scheme = "https"; domain = "alan-big-nixos.tailbb2802.ts.net"; }
        { name = "yt-api"; port = 3015; expose = "tailscale"; scheme = "https"; domain = "alan-big-nixos.tailbb2802.ts.net"; }
        { name = "tv-controller"; port = 3016; streamPort = 1234; expose = "tailscale"; scheme = "https"; domain = "alan-big-nixos.tailbb2802.ts.net"; }
        { name = "invidious"; port = 3017; expose = "tailscale"; scheme = "https"; domain = "alan-big-nixos.tailbb2802.ts.net"; }
        { name = "n8n"; port = 3018; expose = "tailscale"; scheme = "https"; domain = "alan-big-nixos.tailbb2802.ts.net"; }
        { name = "open-webui"; port = 3019; expose = "tailscale"; scheme = "https"; domain = "alan-big-nixos.tailbb2802.ts.net"; }
        # { name = "vaultwarden"; port = 3020; expose = "tailscale"; scheme = "https"; domain = "alan-big-nixos.tailbb2802.ts.net"; }
        # { name = "collabora"; port = 3021; expose = "tailscale"; scheme = "https"; domain = "alan-big-nixos.tailbb2802.ts.net"; }
        # { name = "immich"; port = 3022; expose = "tailscale"; scheme = "https"; domain = "alan-big-nixos.tailbb2802.ts.net"; }
        # { name = "wordpress"; port = 3023; expose = "tailscale"; scheme = "https"; domain = "alan-big-nixos.tailbb2802.ts.net"; }
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
        ../system/podman.nix
        ../hardware/vulkan.nix
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
      timezone = "America/New_York";
      desktop = "gnome";
      services = [
        { name = "dashboard"; port = 3010; expose = "caddy-wan"; scheme = "https"; host = "www.zabuddia.org"; }
        { name = "gitea"; port = 3011; expose = "caddy-wan"; scheme = "https"; host = "git.zabuddia.org"; }
        { name = "guacamole"; port = 3012; expose = "caddy-wan"; scheme = "https"; host = "guacamole.zabuddia.org"; }
        { name = "nextcloud"; port = 3013; expose = "caddy-wan"; scheme = "https"; host = "nextcloud.zabuddia.org"; }
        { name = "tv-controller"; port = 3014; streamPort = 1234; expose = "caddy-wan"; scheme = "https"; host = "tv.zabuddia.org"; }
        { name = "invidious"; port = 3015; expose = "caddy-wan"; scheme = "https"; host = "youtube.zabuddia.org"; }
        { name = "n8n"; port = 3016; expose = "caddy-wan"; scheme = "https"; host = "n8n.zabuddia.org"; }
        { name = "open-webui"; port = 3017; expose = "caddy-wan"; scheme = "https"; host = "llm.zabuddia.org"; }
        { name = "vaultwarden"; port = 3018; expose = "caddy-wan"; scheme = "https"; host = "vault.zabuddia.org"; }
        { name = "temple-ready"; port = 3019; expose = "caddy-wan"; scheme = "https"; host = "temple-ready.zabuddia.org"; }
        { name = "collabora"; port = 3020; expose = "caddy-wan"; scheme = "https"; host = "office.zabuddia.org"; }
        { name = "immich"; port = 3021; expose = "caddy-wan"; scheme = "https"; host = "photos.zabuddia.org"; }
        { name = "wordpress"; port = 3022; expose = "caddy-wan"; scheme = "https"; host = "blog.zabuddia.org"; }
        { name = "tsduck"; streamPort = 3023; expose = "caddy-wan"; scheme = "https"; host = "tsduck.zabuddia.org"; }
        # I can't figure out how to change the jellyfin port so it is 8096
        { name = "jellyfin"; port = 8096; expose = "caddy-wan"; scheme = "https"; host = "jellyfin.zabuddia.org"; }
        # { name = "dashboard"; port = 3000; expose = "tailscale"; scheme = "https"; domain = "nixos-home.tailbb2802.ts.net"; }
        # { name = "gitea"; port = 3001; expose = "tailscale"; scheme = "https"; domain = "nixos-home.tailbb2802.ts.net"; }
        # { name = "pyhttp"; port = 3002; expose = "tailscale"; scheme = "https"; domain = "nixos-home.tailbb2802.ts.net"; }
        # { name = "guacamole"; port = 3003; expose = "tailscale"; scheme = "https"; domain = "nixos-home.tailbb2802.ts.net"; }
        # { name = "nextcloud"; port = 3004; expose = "tailscale"; scheme = "https"; domain = "nixos-home.tailbb2802.ts.net"; }
        # { name = "yt-api"; port = 3005; expose = "tailscale"; scheme = "https"; domain = "nixos-home.tailbb2802.ts.net"; }
        # { name = "tv-controller"; port = 3006; streamPort = 1234; expose = "tailscale"; scheme = "https"; domain = "nixos-home.tailbb2802.ts.net"; }
        # { name = "invidious"; port = 3007; expose = "tailscale"; scheme = "https"; domain = "nixos-home.tailbb2802.ts.net"; }
        # { name = "n8n"; port = 3008; expose = "tailscale"; scheme = "https"; domain = "nixos-home.tailbb2802.ts.net"; }
        # { name = "open-webui"; port = 3009; expose = "tailscale"; scheme = "https"; domain = "nixos-home.tailbb2802.ts.net"; }
      ];
      # llms = [
      #   { name = "qwen3"; model = "qwen3-8b"; port = 8000; device = "Vulkan1"; }
      # ];
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
        # ../system/llama-cpp.nix
        ../system/podman.nix
        ../system/uxplay.nix
        # ../system/m3u-tuner.nix
	      ../system/auto-login.nix
        ../system/always-on.nix
        ../hardware/vulkan.nix
        ../hardware/all-firmware.nix
      ];
      systemPackages = [
        "rpi-imager"
      ];
    }
    rec {
      name = "llm-home";
      system = "x86_64-linux";
      timezone = "America/New_York";
      desktop = "headless";
      services = [ ];
      llms = [
        { name = "gpt-oss-cline"; model = "gpt-oss-20b"; port = 8000; ctxSize = 24576; device = 0; useClineGrammar = true; }
        { name = "qwen3"; model = "qwen3-14b"; port = 8001; ctxSize = 16384; chatTemplate = "chatml"; device = 1; }
        { name = "qwen2.5-coder"; model = "qwen2.5-coder-7b"; port = 8002; ctxSize = 8192; chatTemplate = "chatml"; device = "2"; }
        { name = "nomic-embed"; model = "nomic-embed-v2-moe"; port = 8003; device = "3"; }
      ];
      modules = [
        ../../hosts/llm-home-hardware.nix
        ../system/ssh.nix
        ../system/dev.nix
        ../system/tailscale.nix
        ../system/llama-cpp.nix
        ../system/fix-codium-server.nix
        ../hardware/vulkan.nix
        ../hardware/rocm.nix
        ../hardware/all-firmware.nix
      ];
      systemPackages = [ ];
    }
    rec {
      name = "randy-laptop-nixos";
      system = "x86_64-linux";
      timezone = "America/New_York";
      desktop = "gnome";
      services = [ ];
      modules = [
        ../../hosts/randy-laptop-nixos-hardware.nix
        ../system/dev.nix
        ../system/tailscale.nix
        ../system/waydroid.nix
        ../system/tor.nix
        ../system/flatpak.nix
        ../system/rpi-imager.nix
        ../system/vm.nix
        ../system/remote-desktop.nix
        ../system/sunshine.nix
        ../system/droidcam.nix
        ../system/podman.nix
        ../system/uxplay.nix
        ../hardware/all-firmware.nix
      ];
      systemPackages = [ ];
    }
  ];
}
