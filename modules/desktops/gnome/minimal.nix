{ pkgs }:
{
  environment.gnome.excludePackages = with pkgs; [
    geary
    epiphany
    totem
    simple-scan
    xterm
    gnome-music
    gnome-maps
    gnome-photos
    gnome-tour
    gnome-characters
    gnome-contacts
    gnome-clocks
    gnome-calendar
    gnome-weather
  ];
}
