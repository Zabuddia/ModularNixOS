{ scheme, host, port }:

{ config, lib, pkgs, ... }:
{
  services.gitea = {
    enable = true;
    settings.server = {
      DOMAIN   = host;
      ROOT_URL = "${scheme}://${host}/";
      HTTP_PORT = port;
    };
  };
}