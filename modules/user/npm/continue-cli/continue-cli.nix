# First do node2nix -i node-package.json
{ pkgs, ... }:
{
  home.packages = [
    ((import ./default.nix { inherit pkgs; nodejs = pkgs.nodejs_20; })."@continuedev/cli")
  ];
}