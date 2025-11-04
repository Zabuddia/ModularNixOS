{ scheme, host, port, lanPort, streamPort, expose, edgePort }:

{ config, pkgs, lib, ... }:
{
  services.jellyfin = {
    enable = true;
    package = pkgs.jellyfin;
    openFirewall = false;
  };
}