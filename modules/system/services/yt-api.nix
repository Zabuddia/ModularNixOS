{ scheme, host, port, lanPort }:

{ config, lib, pkgs, ... }:
let
  # Python with the libs your app imports
  py = pkgs.python3.withPackages (ps: with ps; [ fastapi uvicorn ]);
in
{
  # Place your app code on disk.
  environment.etc."yt-api/yt-api.py".source = custom/yt-api/yt-api.py;

  systemd.services.yt-api = {
    description = "YouTube download/convert API (FastAPI + yt-dlp + ffmpeg)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    # ffmpeg + yt-dlp on PATH for the service
    path = [ pkgs.ffmpeg pkgs.yt-dlp ];

    serviceConfig = {
      ExecStart = "${py}/bin/uvicorn yt-api:app --host 127.0.0.1 --port ${toString port}";
      WorkingDirectory = "/etc/yt-api";

      DynamicUser = true;
      StateDirectory = "yt-api";  # -> /var/lib/yt-api (writable)
      CacheDirectory = "yt-api";  # -> /var/cache/yt-api (writable)

      # Point yt-dlp to the writable cache; also give it a sane HOME
      Environment = [
        "HOME=/var/lib/yt-api"
        "XDG_CACHE_HOME=/var/cache/yt-api"
        "XDG_CONFIG_HOME=/var/lib/yt-api"
      ];

      Restart = "on-failure";
      RestartSec = 3;
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
    };
  };
}