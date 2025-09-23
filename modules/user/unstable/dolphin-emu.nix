# This is impure. It is here to get the latest version of dolphin
{ pkgs, ... }:
let
  unstable = builtins.getFlake "github:NixOS/nixpkgs/nixos-unstable";
  dolphin  = unstable.legacyPackages.${pkgs.system}.dolphin-emu;
in {
  home.packages = [ dolphin ];
}