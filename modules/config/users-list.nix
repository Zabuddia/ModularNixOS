{
  users = [
    {
      name = "buddia";
      fullName = "Alan Fife";
      email = "fife.alan@gmail.com";
      hashedPassword = "$y$j9T$I8EQYRnAKlWsvquySBpRE1$7fyHAZ/84X2fY1FiX7TVavbtn2FB0/15HsSUBSTgM9A";
      groups = [ "wheel" "networkmanager" ];
      shell = "bash";

      desktop = {
        gnome = import ../desktops/empty.nix;
        plasma = import ../desktops/empty.nix;
        cinnamon = import ../desktops/empty.nix;
        pantheon = import ../desktops/empty.nix;
      };
    }
  ];
}
