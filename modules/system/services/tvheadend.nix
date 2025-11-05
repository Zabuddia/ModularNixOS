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
    ports = [ "${toS port}:9981" ];
    volumes = [
      "${dataDir}:/config"
      "/etc/localtime:/etc/localtime:ro"
    ];
    extraOptions = [
      "--device=/dev/dvb"     # adjust if your tuner path differs
    ];
    environment.TZ = config.time.timeZone or "UTC";
    autoStart = true;
  };
}