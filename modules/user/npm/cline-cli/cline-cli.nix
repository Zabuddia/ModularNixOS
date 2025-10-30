{ pkgs, ... }:
let
  node = import ./composition.nix { inherit pkgs; };
  cline = node.packageOverrides."cline";
in {
  home.packages = [ cline ];
}