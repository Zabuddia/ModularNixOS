{ lib, pkgs, hostPackages, ... }:

let
  resolve = names:
    map (n:
      if lib.hasAttr n pkgs then builtins.getAttr n pkgs
      else throw "hosts.nix: unknown system package '${n}'"
    ) names;
in
{
  environment.systemPackages = resolve hostPackages;
}
