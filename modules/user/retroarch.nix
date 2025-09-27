{ pkgs, ... }:

{
  home.packages = with pkgs; [
    retroarch
    retroarchCores.dolphin
  ];
}