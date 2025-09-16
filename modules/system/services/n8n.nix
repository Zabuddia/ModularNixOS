{ scheme, host, port }:

{ config, pkgs, lib, ... }:
{
  services.n8n = {
    enable = true;
    # openFirewall = true;

    settings = {
      N8N_SECURE_COOKIE = false;
    };
  };

  systemd.services.n8n.environment = {
    N8N_PORT = builtins.toString port;
    N8N_HOST = host;
    WEBHOOK_URL = lib.mkForce "${scheme}://${host}/";
  };
}