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
  services.seafile-server = {
    enable = true;
    package = pkgs.seafile-server;

    # Seafile listens on localhost; TLS handled by proxy
    fastcgi.enable = false;
    ccnetSettings.General.SERVICE_URL = externalURL;

    # Default ports
    seafilePort = port;
    seahubPort = port + 1;

    # Data storage directory
    dataDir = "/srv/seafile";
  };
}