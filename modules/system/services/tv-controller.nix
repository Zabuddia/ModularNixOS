{ scheme, host, port, lanPort, streamPort, expose, edgePort }:

{ config, lib, pkgs, ... }:
let
  # Python runtime with Flask + gunicorn
  py = pkgs.python3.withPackages (ps: with ps; [ flask gunicorn ]);
in
{
  #### Install your app files
  environment.etc."tv-controller/tv-controller.py".source = custom/tv-controller/tv-controller.py;
  environment.etc."tv-controller/index.html".source = custom/tv-controller/index.html;

  # NEW: install the favicon
  environment.etc."tv-controller/favicon.ico".source = custom/tv-controller/favicon.ico;

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

    path = [ pkgs.vlc pkgs.w_scan2 pkgs.coreutils pkgs.bash ];

    serviceConfig = {
      StateDirectory = "tv-controller";
      WorkingDirectory = "/var/lib/tv-controller";

      # Each line becomes an ExecStartPre= entry (correct systemd syntax)
      ExecStartPre = [
        "${pkgs.coreutils}/bin/install -D -m0644 /etc/tv-controller/index.html /var/lib/tv-controller/index.html"
        "${pkgs.coreutils}/bin/install -D -m0644 /etc/tv-controller/tv-controller.py /var/lib/tv-controller/tv-controller.py"
        # NEW: copy favicon into working dir
        "${pkgs.coreutils}/bin/install -D -m0644 /etc/tv-controller/favicon.ico /var/lib/tv-controller/favicon.ico"
        # conditional seed of channels.conf
        "${pkgs.bash}/bin/sh -c '[ -f /var/lib/tv-controller/channels.conf ] || ${pkgs.coreutils}/bin/install -m0644 /etc/tv-controller/channels.conf /var/lib/tv-controller/channels.conf'"
      ];

      ExecStart = ''
        ${py}/bin/gunicorn tv-controller:app \
          --workers 1 \
          --bind 127.0.0.1:${toString port} \
          --chdir /var/lib/tv-controller \
          --timeout 700 \
          --graceful-timeout 700
      '';

      Environment = [
        "FLASK_ENV=production"
        "VLC_HOST=127.0.0.1"
        "VLC_PORT=${toString streamPort}"
        "CHANNELS_CONF_PATH=/var/lib/tv-controller/channels.conf"
      ];

      DynamicUser = true;
      SupplementaryGroups = [ "video" "audio" ];
      Restart = "on-failure";
      RestartSec = 3;
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
    };
  };
}