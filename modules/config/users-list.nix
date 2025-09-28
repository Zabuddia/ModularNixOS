# To make the hashedPassword do mkpasswd -m yescrypt
# To make the sha256Password do printf 'YOUR_PASSWORD' | sha256sum | cut -d' ' -f1
{
  users = [
    {
      name = "buddia";
      fullName = "Alan Fife";
      email = "fife.alan@protonmail.com";
      hashedPassword = "$y$j9T$I8EQYRnAKlWsvquySBpRE1$7fyHAZ/84X2fY1FiX7TVavbtn2FB0/15HsSUBSTgM9A";
      sha256Password = "0e2d01df49fceefb333187abc077ddf00e3df31494bc38a86fbce8180ee0e666";
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
          ../user/distrobox.nix
          ../user/retroarch.nix
          ../user/unstable/dolphin-emu.nix
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
          # "retroarch"
          "ryubing"
        ];
      };
    }
    {
      name = "buddiardp";
      fullName = "Alan Fife RDP";
      email = "fife.alan@protonmail.com";
      hashedPassword = "$y$j9T$I8EQYRnAKlWsvquySBpRE1$7fyHAZ/84X2fY1FiX7TVavbtn2FB0/15HsSUBSTgM9A";
      sha256Password = "0e2d01df49fceefb333187abc077ddf00e3df31494bc38a86fbce8180ee0e666";
      groups = [ "wheel" "networkmanager" ];
      shell = "bash";

      hosts = [ "alan-mba-2013" "alan-big-nixos" ];

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
          ../user/distrobox.nix
          ../user/retroarch.nix
          ../user/dolphin-emu.nix
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
          # "retroarch"
          "ryubing"
        ];
      };
    }
  ];
}
