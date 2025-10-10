{ scheme, host, port, lanPort, streamPort, expose, edgePort }:

{ config, lib, pkgs, ... }:
{
  services.gitea = {
    enable = true;
    settings.server = {
      HTTP_ADDR = "127.0.0.1";
      DOMAIN = host;
      ROOT_URL = "${scheme}://${host}/";
      HTTP_PORT = port;
    };
  };
}