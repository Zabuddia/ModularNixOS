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
  services.vikunja = {
    enable = true;
    package = pkgs.vikunja;

    # Vikunja listens here; your caddy auto-expose should reverse_proxy to this port.
    port = port;

    # Tell Vikunja what URL users will use to reach it (important for links, redirects, etc.)
    frontendScheme = scheme;
    frontendHostname = host;

    # Keep it local; caddy will front it
    settings.service = {
      interface = "127.0.0.1";
      publicurl = externalURL + "/";

      # simple defaults (optional)
      # enableemailreminders = false;
      # enableregistration = false;
    };

    # simplest DB
    database = {
      type = "sqlite";
      path = "/var/lib/vikunja/vikunja.sqlite";
    };
  };
}