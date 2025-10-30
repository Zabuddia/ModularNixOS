{ pkgs, ... }:
{
  home.packages = [
    ((import ./default.nix { inherit pkgs; nodejs = pkgs.nodejs_20; }).cline)
  ];
}