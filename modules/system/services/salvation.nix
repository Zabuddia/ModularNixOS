{ scheme, host, port, lanPort, streamPort, expose, edgePort }:

{ config, lib, pkgs, ... }:
let
  inherit (lib) optionalAttrs;

  # Python env for this app's current requirements
  py = pkgs.python3.withPackages (ps: with ps; [
    # core web stack
    flask flask-login flask-sqlalchemy flask-wtf gunicorn
    jinja2 markupsafe itsdangerous werkzeug click
    sqlalchemy
    typing-extensions

    # utils / runtime deps
    python-dateutil pytz tzdata packaging idna six greenlet
    python-dotenv
    pandas numpy
    lxml
  ]);

  # external URL pieces
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
  ## Install app sources into /etc
  ############################################
  environment.etc =
    (optionalAttrs (builtins.pathExists ./app) {
      "salvation/app".source = ./app;
    })
    //
    (optionalAttrs (builtins.pathExists ./run.py) {
      "salvation/run.py".source = ./run.py;
    });

  ############################################
  ## Dedicated runtime user/group
  ############################################
  users.users.salvation = {
    isSystemUser = true;
    group = "salvation";
    home = "/var/lib/salvation";
  };
  users.groups.salvation = {};

  ############################################
  ## Systemd service
  ############################################
  systemd.services.salvation = {
    description = "Salvation (Flask + Gunicorn)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    # No Java needed for this version (no tabula-py/PDF parsing)
    path = [ pkgs.coreutils pkgs.bash pkgs.rsync ];

    serviceConfig = {
      StateDirectory = "salvation";
      WorkingDirectory = "/var/lib/salvation";

      # Run pre-commands as root, then chown to service user
      PermissionsStartOnly = true;

      ExecStartPre = [
        "${pkgs.rsync}/bin/rsync -a --delete /etc/salvation/app/ /var/lib/salvation/app/"
        "${pkgs.coreutils}/bin/install -D -m0644 /etc/salvation/run.py /var/lib/salvation/run.py"
        "${pkgs.coreutils}/bin/mkdir -p /var/lib/salvation/instance"
        "${pkgs.coreutils}/bin/chown -R salvation:salvation /var/lib/salvation"
        "${pkgs.coreutils}/bin/chmod -R u+rwX /var/lib/salvation"
      ];

      ExecStart = ''
        ${py}/bin/gunicorn run:app \
          --workers 3 \
          --bind ${bindAddr}:${toString port} \
          --chdir /var/lib/salvation \
          --timeout 120 \
          --graceful-timeout 120
      '';

      Environment = [
        "FLASK_ENV=production"
        "FLASK_APP=run.py"
        "EXTERNAL_URL=${externalURL}"
        "SECRET_KEY=change-me-in-your-module-or-secrets"
        "DATABASE_URL=sqlite:///app.sqlite3"
        "MAX_CONTENT_LENGTH=16777216"
        "MAX_FORM_MEMORY_SIZE=16777216"
      ];

      User = "salvation";
      Group = "salvation";

      Restart = "on-failure";
      RestartSec = 3;

      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
    };
  };
}