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

    # Vaultwarden listens only on localhost; expose via LAN or Caddy separately
    config = {
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = port;

      DOMAIN = externalURL;
      WEBSOCKET_ENABLED = true;
      SIGNUPS_ALLOWED = false;
      # If using a reverse proxy, trusting it helps with correct client IPs:
      # (Caddy sets X-Forwarded-For/X-Real-IP)
      # IP_HEADER = "X-Forwarded-For";
    };

    # If you keep secrets in /etc/vaultwarden.env, uncomment:
    # environmentFile = "/etc/vaultwarden.env";

    # Optional backups
    backupDir = "/var/lib/vaultwarden/backups";
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/vaultwarden 0750 vaultwarden vaultwarden -"
  ];
}