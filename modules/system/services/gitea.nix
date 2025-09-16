{ config, pkgs, ... }:

let
  host = config.networking.hostName;
in
{
  services.gitea = {
    enable = true;
    settings.server.DOMAIN = host;
    settings.server.ROOT_URL = "http://${host}:3000/";
    settings.server.HTTP_PORT = 3000;
  };
}