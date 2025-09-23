{ pkgs, ... }:
let
  dolphin = (builtins.getFlake "github:matthewcroughan/dolphin-emu-nix").packages.${pkgs.system}.dolphin-emu;
in {
  home.packages = [ dolphin ];
}