{
  users = [
    {
      name = "buddia";
      fullName = "Alan Fife";
      email = "fife.alan@protonmail.com";
      hashedPassword = "$y$j9T$I8EQYRnAKlWsvquySBpRE1$7fyHAZ/84X2fY1FiX7TVavbtn2FB0/15HsSUBSTgM9A";
      groups = [ "wheel" "networkmanager" ];
      shell = "bash";

      hosts = [ "alan-mba-2013" "alan-laptop-nixos" "alan-big-nixos" ];

      desktop = {
        gnome = ../desktops/gnome/ubuntu.nix;
        plasma = ../desktops/plasma/default.nix;
      };

      hm = {
        imports = [
          ../user/librewolf.nix
          ../user/firefox.nix
          ../user/chromium.nix
          ../user/git.nix
          ../user/codium.nix
          ../user/nextcloud-client.nix
          ../user/tailscale-systray.nix
        ];

        packages = [
          "bluebubbles"
          "sparrow"
          "xournalpp"
          "libreoffice"
          "impression"
          "remmina"
          "moonlight-qt"
          "prismlauncher"
          "dolphin-emu"
        ];
      };
    }
    {
      name = "buddia RDP";
      fullName = "Alan Fife RDP";
      email = "fife.alan@protonmail.com";
      hashedPassword = "$y$j9T$I8EQYRnAKlWsvquySBpRE1$7fyHAZ/84X2fY1FiX7TVavbtn2FB0/15HsSUBSTgM9A";
      groups = [ "wheel" "networkmanager" ];
      shell = "bash";

      hosts = [ "alan-big-nixos" ];

      desktop = {
        gnome = ../desktops/gnome/ubuntu.nix;
        plasma = ../desktops/plasma/default.nix;
      };

      hm = {
        imports = [
          ../user/librewolf.nix
          ../user/firefox.nix
          ../user/chromium.nix
          ../user/git.nix
          ../user/codium.nix
          ../user/nextcloud-client.nix
          ../user/tailscale-systray.nix
        ];

        packages = [
          "bluebubbles"
          "sparrow"
          "xournalpp"
          "libreoffice"
          "impression"
          "remmina"
          "moonlight-qt"
          "prismlauncher"
          "dolphin-emu"
        ];
      };
    }
  ];
}
