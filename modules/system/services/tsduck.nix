{ scheme, host, port, lanPort, streamPort, expose, edgePort }:

{ config, pkgs, lib, ... }:
let
  inherit (lib) mkIf mkMerge;
  svcName = "tsduck-hls";
  hlsDir = "/var/lib/${svcName}";
in
mkMerge [
  {
    ############################################################
    ## Packages & directories
    ############################################################
    environment.systemPackages = [ pkgs.tsduck ];

    systemd.tmpfiles.rules = [
      "d ${hlsDir} 0755 root root -"
    ];

    ############################################################
    ## TSDuck HLS streamer service
    ############################################################
    systemd.services.${svcName} = {
      description = "TSDuck DVB HLS Streamer (HTTP passthrough)";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        Type = "simple";
        Restart = "always";
        RestartSec = 5;

        ExecStart = ''
          mkdir -p ${hlsDir}
          # The HTTP output lets Jellyfin/Kodi fetch segments dynamically via /stream
          exec ${pkgs.tsduck}/bin/tsp \
            -I dvb --adapter 0 --delivery DVB-T --frequency 573000000 \
            -P regulate \
            -O http \
              --server 127.0.0.1:${toString streamPort} \
              --resource /stream \
              --hls-playlist /playlist.m3u8 \
              --hls-directory ${hlsDir} \
              --hls-segment-duration 4 \
              --hls-list-size 8
        '';
      };
    };
  }
]