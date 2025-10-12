{ scheme, host, port, lanPort, streamPort, expose, edgePort }:

{ config, lib, pkgs, ... }:
let
  extPort =
    if expose == "caddy-wan" then edgePort else lanPort;

  extPortSuffix =
    if extPort == null || extPort == 80 || extPort == 443 then "" else ":${toString extPort}";

  externalURL = "${scheme}://${host}${extPortSuffix}";

  hostRegex      = builtins.replaceStrings [ "." ] [ "\\." ] host;
  hostnameRegex  = builtins.replaceStrings [ "." ] [ "\\." ] config.networking.hostName;
in
{
  services.collabora-online = {
    enable = true;

    # Collabora listens on loopback; terminate TLS elsewhere if you want it.
    port = port;
    extraArgs = [ "--o:ssl.enable=false" ];

    # Keep origin allowlist minimal: public host (+ localhost, + machine hostname).
    aliasGroups = [
      {
        host = host;
        aliases = [ hostRegex "localhost" hostnameRegex ];
      }
    ];
  };

  # Export the public URL so nextcloud.nix can pick it up as `collabora.url`.
  _module.args.collabora = {
    url = externalURL;
  };
}