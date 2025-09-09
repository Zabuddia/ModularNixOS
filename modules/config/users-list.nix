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
        gnome = import ../desktops/gnome/ubuntu.nix;
        plasma = import ../desktops/plasma/default.nix;
      };
    }
  ];
}
