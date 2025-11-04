{ scheme, host, port, lanPort, streamPort, expose, edgePort }:

{ pkgs, ... }:
{
  services.jellyfin = {
    enable = true;
    package = pkgs.jellyfin;
    openFirewall = false;
  };

  # Force Jellyfin to use your chosen port
  systemd.services.jellyfin.serviceConfig.ExecStart = [
    "${pkgs.jellyfin}/bin/jellyfin --httpport ${toString port}"
  ];
}