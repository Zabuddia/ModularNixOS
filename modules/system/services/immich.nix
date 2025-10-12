{ scheme, host, port, lanPort, streamPort, expose, edgePort }:

{ config, lib, pkgs, ... }:
let
  extPort =
    if expose == "caddy-wan" then edgePort else lanPort;

  extPortSuffix =
    if extPort == null || extPort == 80 || extPort == 443 then "" else ":${toString extPort}";

  externalURL = "${scheme}://${host}${extPortSuffix}";
in
{
  services.immich = {
    enable = true;
    host = "127.0.0.1";
    port = port;

    redis.enable = true;
    database.enable = true;
    mediaLocation = "/srv/immich";

    settings.server.externalDomain = externalURL;
  };
}