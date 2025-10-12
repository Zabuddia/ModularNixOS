{ scheme, host, port, lanPort, streamPort, expose, edgePort }:

{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf;
  extPort =
    if expose == "caddy-wan" then edgePort else lanPort;

  extPortSuffix =
    if extPort == null || extPort == 80 || extPort == 443 then "" else ":${toString extPort}";

  externalURL = "${scheme}://${host}${extPortSuffix}";
  hostRegex   = builtins.replaceStrings [ "." ] [ "\\." ] host;
in
{
  services.collabora-online = {
    enable = true;

    # Collabora listens on loopback; terminate TLS elsewhere if you want it.
    port = port;
    extraArgs = [ "--o:ssl.enable=false" ];

    # Allow your external host to reach Collabora (WOPI origin checks).
    # Keep this minimal: just the public host (and localhost).
    aliasGroups = [
      {
        host = host;
        aliases = [ hostRegex "localhost" ];
      }
    ];
  };

  config._module.args.collabora = {
    url = externalURL;
  };

  # (FYI) externalURL is what Nextcloud's richdocuments.wopi_url should use.
  # Set it wherever your Nextcloud module lives:
  #   nextcloud-occ config:app:set richdocuments wopi_url --value=${externalURL}
}