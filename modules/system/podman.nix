{ config, pkgs, ... }:

{
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;  # 'docker' CLI maps to podman
  };

  # ensure the rootful podman socket runs
  systemd.services."podman.socket".wantedBy = [ "sockets.target" ];

  # make docker.sock always point to podman.sock
  systemd.tmpfiles.rules = [
    "L /var/run/docker.sock - - - - /var/run/podman/podman.sock"
  ];
}