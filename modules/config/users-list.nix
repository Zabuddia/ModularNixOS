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
      groups = [ "wheel" "networkmanager" "video" ];
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
          ../user/unstable/sm64coopdx.nix
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
          "ryubing"
          "anki"
          "aider-chat"
        ];
      };
    }
    {
      name = "buddiardp";
      fullName = "Alan Fife RDP";
      email = "fife.alan@protonmail.com";
      hashedPassword = "$y$j9T$I8EQYRnAKlWsvquySBpRE1$7fyHAZ/84X2fY1FiX7TVavbtn2FB0/15HsSUBSTgM9A";
      sha256Password = "0e2d01df49fceefb333187abc077ddf00e3df31494bc38a86fbce8180ee0e666";
      groups = [ "wheel" "networkmanager" "video" ];
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
          "ryubing"
        ];
      };
    }
    {
      name = "waffleiron";
      fullName = "Randy Fife";
      email = "fife.randy@protonmail.com";
      hashedPassword = "$y$j9T$Vpj96oGOfDSPGaWzro.fi/$IV/XLfQYbtL/eRyUBP7bRg/rH3KjoIq./q0Qev053x/";
      sha256Password = "b99ca5503eee9a4b172b712d123ab42926d5cc6ec701ef0c0961eb52c406a334";
      groups = [ "wheel" "networkmanager" "video" ];
      shell = "bash";

      hosts = [ "nixos-home" ];

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
          ../user/tailscale-systray.nix
          ../user/distrobox.nix
        ];

        packages = [
          "sparrow"
          "xournalpp"
          "libreoffice"
          "impression"
          "remmina"
          "moonlight-qt"
        ];
      };
    }
  ];
}
