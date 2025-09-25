{ scheme, host, port, lanPort }:

{ config, lib, pkgs, ... }:
let
  # Python with the libs your app imports
  py = pkgs.python3.withPackages (ps: with ps; [ fastapi uvicorn ]);
in
{
  # Place your app code on disk.
  environment.etc."yt-api/yt_api.py".source = custom/yt-api/yt_api.py;

  systemd.services.yt-api = {
    description = "YouTube download/convert API (FastAPI + yt-dlp + ffmpeg)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    # ffmpeg + yt-dlp on PATH for the service
    path = [ pkgs.ffmpeg pkgs.yt-dlp ];

    serviceConfig = {
      # Bind to loopback and the provided port; reverse proxy can use scheme/host.
      ExecStart = "${py}/bin/uvicorn yt_api:app --host 127.0.0.1 --port ${toString port}";
      WorkingDirectory = "/etc/yt-api";

      DynamicUser = true;
      Restart = "on-failure";
      RestartSec = 3;

      # Simple hardening
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
    };
  };

  # Notes:
  # - scheme/host are intentionally not used by the service (it’s just an app server).
  #   Your reverse proxy (nginx/caddy/traefik) should expose ${scheme}://${host}/
  #   and forward to 127.0.0.1:${toString port}.
  # - lanPort is accepted for parity with your other modules; uncomment the firewall
  #   line above if you want to expose via your proxy on that port.
}