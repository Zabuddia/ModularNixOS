{ scheme, host, port, lanPort, streamPort, expose, edgePort }:

{ config, pkgs, lib, ... }:
{
  services.n8n = {
    enable = true;

    environment = {
      N8N_SECURE_COOKIE = "false";
      N8N_PORT = builtins.toString port;
      N8N_HOST = host;
      WEBHOOK_URL = "${scheme}://${host}/";
      # If you also need this sometimes:
      # N8N_PROTOCOL = scheme;
    };
  };
}