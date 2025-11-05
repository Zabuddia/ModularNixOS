{ scheme, host, port, lanPort, streamPort, expose, edgePort }:

{ config, pkgs, lib, ... }:
let
  dataDir = "/var/lib/tvheadend";
  toS = builtins.toString;
in
{
  # Ensure config dir exists
  systemd.tmpfiles.rules = [ "d ${dataDir} 0755 root root - -" ];

  # Podman + OCI container
  virtualisation.podman.enable = true;
  virtualisation.oci-containers.backend = "podman";

  virtualisation.oci-containers.containers.tvheadend = {
    image = "lscr.io/linuxserver/tvheadend:latest";
    ports = [
      "${toS lanPort}:9981"   # Web UI
      "${toS streamPort}:9982" # HTSP (Kodi, etc.)
    ];
    volumes = [
      "${dataDir}:/config"
      "/etc/localtime:/etc/localtime:ro"
    ];
    extraOptions = [
      "--device=/dev/dvb"     # adjust if your tuner path differs
    ];
    environment = {
      TZ = config.time.timeZone or "UTC";
      # Optionally set these if you want specific host UID/GID ownership:
      # PUID = "1000";
      # PGID = "1000";
    };
    autoStart = true;
    restart = "unless-stopped";
  };
}