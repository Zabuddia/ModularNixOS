{ lib, pkgs, hostSpec, ... }:

let
  resolvePkgNames = names:
    map (n:
      if lib.hasAttr n pkgs
      then builtins.getAttr n pkgs
      else throw "hosts.nix: unknown system package '${n}' (not in pkgs)"
    ) names;

  hostPkgs = resolvePkgNames (hostSpec.systemPackages);
in
{
  environment.systemPackages = (hostPkgs);
}
