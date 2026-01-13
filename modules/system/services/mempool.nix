{ scheme, host, port, lanPort, expose, edgePort, ... }:

{ config, lib, pkgs, ... }:
let
  extPort = if expose == "caddy-wan" then edgePort else lanPort;

  extPortSuffix =
    if extPort == null || extPort == 80 || extPort == 443
    then ""
    else ":${toString extPort}";

  externalURL = "${scheme}://${host}${extPortSuffix}";
in
{
  services.mempool.enable = true;

  services.mempool.frontend.address = "127.0.0.1";
  services.mempool.frontend.port = port;
}
