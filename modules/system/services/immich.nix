{ scheme, host, port, lanPort, streamPort, expose, edgePort }:

{ config, lib, pkgs, unstablePkgs, ... }:
let
  extPort =
    if expose == "caddy-wan" then edgePort else lanPort;

  extPortSuffix =
    if extPort == null || extPort == 80 || extPort == 443 then "" else ":${toString extPort}";

  externalURL = "${scheme}://${host}${extPortSuffix}";
in
{
  # Ensure the storage paths exist *before* Immich starts, with correct owner/perm.
  systemd.tmpfiles.rules = [
    "d /srv                     0755 root   root   -"
    "d /srv/immich              0750 immich immich -"
    "d /srv/immich/encoded-video 0750 immich immich -"
    "d /srv/immich/library       0750 immich immich -"
    "d /srv/immich/profile       0750 immich immich -"
    "d /srv/immich/thumbs        0750 immich immich -"
    "d /srv/immich/upload        0750 immich immich -"
  ];

  services.immich = {
    enable = true;
    package = unstablePkgs.immich;

    # Bind to loopback; your proxy handles WAN/LAN exposure.
    host = "127.0.0.1";
    port = port;

    mediaLocation = "/srv/immich";

    # Built-in Redis + Postgres, fully declarative DB init.
    redis.enable = true;
    database = {
      enable = true;
      createDB = true;
      name = "immich";
      user = "immich";

      enableVectors = true;        # provide $libdir/vectors
      enableVectorChord = false;   # avoid switching extensions right now
    };

    settings.server.externalDomain = externalURL;

    machine-learning = {
      enable = true;
      environment = {
        MACHINE_LEARNING_PORT = "3003";
      };
    };
  };
}