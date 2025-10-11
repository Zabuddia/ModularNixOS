{ scheme, host, port, lanPort, streamPort, expose, edgePort }:

{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf;
  extPort =
    if expose == "caddy-wan" then edgePort else lanPort;

  extPortSuffix =
    if extPort == null || extPort == 80 || extPort == 443 then "" else ":${toString extPort}";

  externalURL = "${scheme}://${host}${extPortSuffix}";
in
{
  services.gitea = {
    enable = true;
    package = pkgs.gitea;

    settings.server = {
      HTTP_ADDR = "127.0.0.1";
      HTTP_PORT = port;
      DOMAIN = host;
      ROOT_URL = externalURL + "/";
    };

    # Optional: if you want repositories stored somewhere specific
    # settings.repository.ROOT = "/var/lib/gitea/data/repositories";
  };
}