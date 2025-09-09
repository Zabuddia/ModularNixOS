# Copy to users-list.nix and fill real data.
# Password: nix shell nixpkgs#whois -c mkpasswd -m yescrypt
{
  users = [
    {
      name = "buddia";
      fullName = "Alan Fife";
      email = "fife.alan@gmail.com";
      hashedPassword = "$y$REPLACE_ME";
      groups = [ "wheel" "networkmanager" ];
      shell = "zsh";

      desktop = {
        gnome = import ../desktops/gnome/default.nix;
        plasma = import ../desktops/plasma/default.nix;
        cinnamon = import ../desktops/cinnamon/default.nix;
        pantheon = import ../desktops/pantheon/default.nix;
      };
    }
  ];
}
