# nix store add-file --hash-type sha256 baserom.us.z64
# or sudo nix-store --add-fixed sha256 baserom.us.z64
{ unstablePkgs, ... }:
{
  home.packages = [ unstablePkgs.sm64coopdx ];
}