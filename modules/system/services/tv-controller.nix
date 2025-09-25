{ scheme, host, port, lanPort }:

{ config, lib, pkgs, ... }:
let
  # Python runtime with Flask + gunicorn
  py = pkgs.python3.withPackages (ps: with ps; [ flask gunicorn ]);

  # Packages the service needs on PATH
  # - vlc provides `cvlc`
  # - w_scan2 is the maintained scanner (if you really need legacy `w_scan`, swap it in)
  svcPath = [ pkgs.vlc pkgs.w_scan2 ];
in
{
  #### Install your app files
  environment.etc."tv-controller/tv-controller.py".source = custom/tv-controller/tv-controller.py;
  environment.etc."tv-controller/index.html".source = custom/tv-controller/index.html;

  # Seed an (empty) channels.conf so the app has a writable baseline; the service
  # will copy it into /var/lib/tv-controller where writes are allowed.
  environment.etc."tv-controller/channels.conf" =
    if builtins.pathExists ./custom/tv-controller/channels.conf then {
      source = ./custom/tv-controller/channels.conf;
    } else {
      text = "";
    };

  #### Service
  systemd.services.tv-controller = {
    description = "ATSC/DVB tuner control + VLC HTTP mux (Flask)";
    wantedBy    = [ "multi-user.target" ];
    after       = [ "network-online.target" ];
    wants       = [ "network-online.target" ];

    path = svcPath;

    serviceConfig = {
      # Create writable state dir: /var/lib/tv-controller
      StateDirectory = "tv-controller";

      # Run from the state dir so your app reads/writes channels.conf & serves index.html
      WorkingDirectory = "/var/lib/tv-controller";

      # On each start, sync the tracked files to the writable state dir
      ExecStartPre = lib.mkAfter ''
        install -D -m0644 /etc/tv-controller/index.html /var/lib/tv-controller/index.html
        install -D -m0644 /etc/tv-controller/tv_controller.py /var/lib/tv-controller/tv-controller.py
        [ -f /var/lib/tv-controller/channels.conf ] || \
          install -m0644 /etc/tv-controller/channels.conf /var/lib/tv-controller/channels.conf
      '';

      # Bind only on loopback; your reverse proxy uses ${scheme}://${host}/ → 127.0.0.1:${port}
      ExecStart = ''
        ${py}/bin/gunicorn tv-controller:app \
          --workers 1 \
          --bind 127.0.0.1:${toString port} \
          --chdir /var/lib/tv-controller
      '';

      # Env: tell your app which VLC HTTP port to use when it runs cvlc
      Environment = [
        "FLASK_ENV=production"
        "VLC_PORT=${toString lanPort}"
      ];

      # Permissions / hardening
      DynamicUser     = true;
      SupplementaryGroups = [ "video" "audio" ];  # access tuner + audio if needed
      Restart         = "on-failure";
      RestartSec      = 3;
      NoNewPrivileges = true;
      ProtectSystem   = "strict";
      ProtectHome     = true;
      PrivateTmp      = true;
      # If you need raw device ACLs beyond group membership, consider:
      # DeviceAllow = [ "/dev/dvb/adapter* rw" ];
    };
  };
}