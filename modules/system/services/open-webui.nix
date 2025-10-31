{ scheme, host, port, lanPort, streamPort, expose, edgePort }:

{ config, pkgs, unstablePkgs, lib, ... }:
let
  # Toggle: true = raw/manual systemd unit, false = normal NixOS module
  useRaw = true;

  inherit (lib) mkIf mkForce mkMerge;

  extPort =
    if expose == "caddy-wan" then edgePort else lanPort;

  extPortSuffix =
    if extPort == null || extPort == 80 || extPort == 443
    then ""
    else ":${toString extPort}";

  externalURL = "${scheme}://${host}${extPortSuffix}";
  owuBin = "${unstablePkgs.open-webui}/bin/open-webui";
in
mkMerge [
  #######################################################
  ## Common user/group & directories
  #######################################################
  {
    users.groups.open-webui = {};
    users.users.open-webui = {
      isSystemUser = true;
      group        = "open-webui";
      home         = "/var/lib/open-webui";
      homeMode     = "0700";
      description  = "Service user for Open WebUI";
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/open-webui        0700 open-webui open-webui -"
      "d /var/lib/open-webui/tmp    0700 open-webui open-webui -"
      "d /var/lib/open-webui/static 0755 open-webui open-webui -"
    ];
  }

  #######################################################
  ## MODE A: RAW / manual service (matches your working CLI)
  #######################################################
  (mkIf useRaw {
    # Make sure the module is off in this mode
    services.open-webui.enable = false;

    systemd.services.open-webui = {
      description = "Open WebUI (clean systemd environment)";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      # Minimal, clean env like your successful manual run
      environment = {
        HOME              = "/var/lib/open-webui";
        LOCALE_ARCHIVE    = "/run/current-system/sw/lib/locale/locale-archive";
        TZDIR             = "${pkgs.tzdata}/share/zoneinfo";
        SSL_CERT_FILE     = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
        NIX_SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
        LANG              = "C.UTF-8";
        LC_ALL            = "C.UTF-8";

        DATA_DIR          = "/var/lib/open-webui";
        TMPDIR            = "/var/lib/open-webui/tmp";
        SQLITE_TMPDIR     = "/var/lib/open-webui/tmp";
        DATABASE_URL      = "sqlite:////var/lib/open-webui/open-webui.db";
        WEBUI_URL         = externalURL;
      };

      serviceConfig = {
        Type = "simple";
        ExecStart = "${owuBin} serve --host 127.0.0.1 --port ${toString port}";

        User = "open-webui";
        Group = "open-webui";
        ReadWritePaths   = [ "/var/lib/open-webui" ];

        Restart    = "on-failure";
        RestartSec = 3;
        UMask      = "0077";

        # Optional hardening you verified
        PrivateTmp       = true;
        ProtectSystem    = "strict";
        ProtectHome      = "read-only";
        NoNewPrivileges  = true;
      };
    };
  })

  #######################################################
  ## MODE B: Normal NixOS module
  #######################################################
  (mkIf (!useRaw) {
    services.open-webui = {
      enable  = true;
      package = unstablePkgs.open-webui;

      host = "127.0.0.1";
      port = port;

      stateDir = "/var/lib/open-webui";
      environment = {
        ENABLE_PERSISTENT_CONFIG = "False";
        ANONYMIZED_TELEMETRY     = "False";
        DO_NOT_TRACK             = "True";
        SCARF_NO_ANALYTICS       = "True";
        WEBUI_AUTH               = "True";
        ENABLE_SIGNUP            = "True";
        DEFAULT_USER_ROLE        = "admin";
        WEBUI_URL                = externalURL;

        # If you want to fix the DB path exactly like raw mode:
        # DATABASE_URL = "sqlite:////var/lib/open-webui/open-webui.db";
      };
    };

    # Ensure the module unit writes to /var/lib/open-webui
    systemd.services.open-webui.serviceConfig = {
      WorkingDirectory = mkForce "/var/lib/open-webui";
      ReadWritePaths   = [ "/var/lib/open-webui" ];
      UMask            = "0077";
    };
  })
]

# sudo -u open-webui env \
#   HOME="/var/lib/open-webui" \
#   DATABASE_URL="sqlite:////var/lib/open-webui/open-webui.db" \
#   DATA_DIR="/var/lib/open-webui" \
#   TMPDIR="/var/lib/open-webui/tmp" \
#   SQLITE_TMPDIR="/var/lib/open-webui/tmp" \
#   strace -f -o /tmp/owu.strace -s 200 \
#   -e trace=openat,statx,rename,unlink,link \
#   bash -lc '
#     cd /var/lib/open-webui
#     exec /nix/store/813kskszk0mbm6dsry953iwcp954qn8d-open-webui-0.6.28/bin/open-webui \
#       serve --host 127.0.0.1 --port 3017
#   '