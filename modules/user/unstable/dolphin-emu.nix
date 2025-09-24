{ unstablePkgs, ... }:
{
  home.packages = [ unstablePkgs.dolphin-emu ];
  imports = [ ../configuration/dolphin-emu-config.nix ];
}