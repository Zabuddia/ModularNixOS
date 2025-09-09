{ pkgs }:
{
  environment.plasma6.excludePackages = with pkgs.kdePackages; [
    discover elisa kcalc kcharselect konversation kweather
    kdepim-addons okular gwenview kmail kaddressbook
  ];
}
