# modules/vikunja.nix
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

    # what you reverse_proxy to (your caddy automation should use this)
    port = port;

    # tells vikunja what hostname/scheme users reach it at
    frontendScheme = scheme;
    frontendHostname = host;

    # sqlite (simple)
    database = {
      type = "sqlite";
      path = "/var/lib/vikunja/vikunja.sqlite";
    };

    # keep this minimal; DO NOT set service.interface (it conflicts)
    settings = {
      service = {
        publicurl = externalURL + "/";

        # optional nice defaults
        # enableemailreminders = false;
        # enableregistration = false;
      };
    };
  };
}
