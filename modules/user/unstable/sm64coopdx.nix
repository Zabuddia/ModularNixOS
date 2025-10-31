# nix store add-file --hash-type sha256 baserom.us.z64
# or sudo nix-store --add-fixed sha256 baserom.us.z64
{ unstablePkgs, ... }:
{
  home.packages = [ unstablePkgs.sm64coopdx ];

  xdg.desktopEntries.sm64coopdx = {
    name = "Super Mario 64 CoopDX";
    comment = "Launch SM64 Cooperative DX";
    exec = "sm64coopdx";
    icon = "sm64coopdx";
    terminal = false;
    categories = [ "Game" ];
  };
}