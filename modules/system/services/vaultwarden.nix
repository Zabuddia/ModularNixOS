{ scheme, host, port, lanPort, streamPort, expose, edgePort }:

{ config, pkgs, lib, ... }:
let
  inherit (lib) mkIf;
  extPort =
    if expose == "caddy-wan" then edgePort else lanPort;

  extPortSuffix =
    if extPort == null || extPort == 80 || extPort == 443 then "" else ":${toString extPort}";

  externalURL = "${scheme}://${host}${extPortSuffix}";
in
{
  services.vaultwarden = {
    enable = true;
    package = pkgs.vaultwarden;
    dbBackend = "sqlite";

    # Bind only locally; expose via LAN or Caddy yourself
    config = {
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = port;
      DOMAIN = externalURL;
      WEBSOCKET_ENABLED = true;
      SIGNUPS_ALLOWED = false;
    };

    # Uncomment if you keep secrets at runtime (not in /nix/store):
    # sudo install -m 0640 -o root -g vaultwarden /dev/null /etc/vaultwarden.env
    # echo 'ADMIN_TOKEN=choose-a-long-random-token' | sudo tee -a /etc/vaultwarden.env >/dev/null
    environmentFile = "/etc/vaultwarden.env";
  };
}