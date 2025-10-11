{ scheme, host, port, lanPort, streamPort, expose, edgePort }:

{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf optionalAttrs;

  # Python env with your requirements
  py = pkgs.python3.withPackages (ps: with ps; [
    # core
    flask flask-login flask-sqlalchemy flask-wtf gunicorn
    jinja2 markupsafe itsdangerous werkzeug click
    sqlalchemy
    typing-extensions
    # utils
    python-dateutil pytz tzdata packaging idna six greenlet
    python-dotenv
    pandas numpy
    pypdf2
    tabula-py          # needs Java at runtime; see `path` below
    dnspython
    et_xmlfile
  ]);

  # external URL pieces (same pattern as your other modules)
  extPort =
    if expose == "caddy-wan" then edgePort else lanPort;
  extPortSuffix =
    if extPort == null || extPort == 80 || extPort == 443 then "" else ":${toString extPort}";
  externalURL = "${scheme}://${host}${extPortSuffix}";

  # bind address policy
  bindAddr = "127.0.0.1";
in
{
  ############################################
  ## Install your app sources into /etc
  ############################################
  environment.etc =
    (optionalAttrs (builtins.pathExists ./custom/temple-ready/app) {
      "temple-ready/app".source = ./custom/temple-ready/app;
    })
    // {
      "temple-ready/run.py".source = ./custom/temple-ready/run.py;
    }
    // (optionalAttrs (builtins.pathExists ./custom/temple-ready/instance) {
      "temple-ready/instance".source = ./custom/temple-ready/instance;
    });

  ############################################
  ## Systemd service
  ############################################
  systemd.services.temple-ready = {
    description = "Temple Ready (Flask + Gunicorn)";
    wantedBy    = [ "multi-user.target" ];
    after       = [ "network-online.target" ];
    wants       = [ "network-online.target" ];

    # Include Java so tabula-py can launch its JVM helper
    path = [ pkgs.coreutils pkgs.bash pkgs.rsync pkgs.jre_headless ];

    serviceConfig = {
      StateDirectory   = "temple-ready";
      WorkingDirectory = "/var/lib/temple-ready";

      ExecStartPre = [
        "${pkgs.rsync}/bin/rsync -a --delete /etc/temple-ready/app/ /var/lib/temple-ready/app/"
        "${pkgs.coreutils}/bin/install -D -m0644 /etc/temple-ready/run.py /var/lib/temple-ready/run.py"
        "${pkgs.bash}/bin/sh -c '[ -d /etc/temple-ready/instance ] && ${pkgs.rsync}/bin/rsync -a /etc/temple-ready/instance/ /var/lib/temple-ready/instance/ || ${pkgs.coreutils}/bin/mkdir -p /var/lib/temple-ready/instance'"
      ];

      ExecStart = ''
        ${py}/bin/gunicorn run:app \
          --workers 3 \
          --bind ${bindAddr}:${toString port} \
          --chdir /var/lib/temple-ready \
          --timeout 120 \
          --graceful-timeout 120
      '';

      Environment = [
        "FLASK_ENV=production"
        "FLASK_APP=run.py"
        "EXTERNAL_URL=${externalURL}"
        # Add your app's env vars here if needed:
        # "DATABASE_URL=sqlite:////var/lib/temple-ready/instance/app.db"
      ];

      DynamicUser = true;
      Restart     = "on-failure";
      RestartSec  = 3;

      NoNewPrivileges = true;
      ProtectSystem   = "strict";
      ProtectHome     = true;
      PrivateTmp      = true;
    };
  };
}