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
  ########################################################################
  ## Users, dirs, and tmpfiles (once)
  ########################################################################
  {
    users.groups.open-webui = {};
    users.users.open-webui = {
      isSystemUser = true;
      group        = "open-webui";
      home         = "/var/lib/open-webui";
      homeMode     = "0700";
      description  = "Service user for Open WebUI";
    };

    # Make sure we always end up with a REAL directory (not a symlink)
    system.activationScripts.fixOpenWebUILink = {
      deps = [ ];
      text = ''
        if [ -L /var/lib/open-webui ]; then
          rm -f /var/lib/open-webui
        fi
        if [ ! -d /var/lib/open-webui ]; then
          install -d -o open-webui -g open-webui -m 0700 /var/lib/open-webui
        fi
        install -d -o open-webui -g open-webui -m 0700 /var/lib/open-webui/tmp
        install -d -o open-webui -g open-webui -m 0700 /var/lib/open-webui/cache
        install -d -o open-webui -g open-webui -m 0700 /var/lib/open-webui/cache/audio/speech
        install -d -o open-webui -g open-webui -m 0755 /var/lib/open-webui/static
      '';
    };

    # Create dirs via tmpfiles (dir, not link)
    systemd.tmpfiles.rules = [
      "d /var/lib/open-webui                       0700 open-webui open-webui -"
      "d /var/lib/open-webui/tmp                   0700 open-webui open-webui -"
      "d /var/lib/open-webui/cache                 0700 open-webui open-webui -"
      "d /var/lib/open-webui/cache/audio/speech    0700 open-webui open-webui -"
      "d /var/lib/open-webui/static                0755 open-webui open-webui -"

      # Guardrails for other services (keep strict)
      "d /var/lib/private 0700 root root -"
      "d /var/cache/private 0700 root root -"
      "d /var/log/private  0700 root root -"
    ];
  }

  ########################################################################
  ## MODE A: RAW / manual service (matches your working CLI)
  ########################################################################
  (mkIf useRaw {
    services.open-webui.enable = false;

    systemd.services.open-webui = {
      description = "Open WebUI (clean systemd environment)";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        HOME              = "/var/lib/open-webui";
        LOCALE_ARCHIVE    = "/run/current-system/sw/lib/locale/locale-archive";
        TZDIR             = "${pkgs.tzdata}/share/zoneinfo";
        SSL_CERT_FILE     = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
        NIX_SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
        LANG              = "C.UTF-8";
        LC_ALL            = "C.UTF-8";

        # App settings
        WEBUI_SECRET_KEY  = "gYg7n2mP4G1gGqk0y8VYsg=="; # replace if desired
        DATA_DIR          = "/var/lib/open-webui";
        TMPDIR            = "/var/lib/open-webui/tmp";
        SQLITE_TMPDIR     = "/var/lib/open-webui/tmp";
        STATIC_DIR        = "/var/lib/open-webui/static";
        DATABASE_URL      = "sqlite:////var/lib/open-webui/open-webui.db";
        WEBUI_URL         = externalURL;

        # Privacy toggles
        ANONYMIZED_TELEMETRY = "False";
        DO_NOT_TRACK         = "True";
        SCARF_NO_ANALYTICS   = "True";
      };

      serviceConfig = {
        Type             = "simple";
        ExecStart        = "${owuBin} serve --host 127.0.0.1 --port ${toString port}";
        User             = "open-webui";
        Group            = "open-webui";

        # IMPORTANT: do NOT chdir into a path behind /var/lib/private
        # (Open WebUI doesn't require a working dir)
        # WorkingDirectory omitted on purpose

        # Only write where you own
        ReadWritePaths = [ "/var/lib/open-webui" ];

        # Prevent systemd from managing /var/lib/private/* for this unit
        DynamicUser      = mkForce false;
        StateDirectory   = mkForce "";
        RuntimeDirectory = mkForce "";
        CacheDirectory   = mkForce "";
        LogsDirectory    = mkForce "";

        PermissionsStartOnly = true;
        ExecStartPre = [
          "${pkgs.coreutils}/bin/install -d -o open-webui -g open-webui -m 0700 /var/lib/open-webui/tmp"
          "${pkgs.coreutils}/bin/install -d -o open-webui -g open-webui -m 0700 /var/lib/open-webui/cache"
          "${pkgs.coreutils}/bin/install -d -o open-webui -g open-webui -m 0700 /var/lib/open-webui/cache/audio/speech"
          "${pkgs.coreutils}/bin/chown -R open-webui:open-webui /var/lib/open-webui"
        ];

        Restart    = "on-failure";
        RestartSec = 3;
        UMask      = "0077";

        # Hardening
        PrivateTmp      = true;
        ProtectSystem   = "strict";
        ProtectHome     = "read-only";
        NoNewPrivileges = true;
      };
    };
  })

  ########################################################################
  ## MODE B: NixOS module (flip useRaw = false)
  ########################################################################
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

        # Uncomment to mirror raw DB path:
        # DATABASE_URL = "sqlite:////var/lib/open-webui/open-webui.db";
      };
    };

    # Override the unit that HM/module generates to keep it out of /var/lib/private
    systemd.services.open-webui.serviceConfig = {
      # Avoid CHDIR behind /var/lib/private; not needed anyway
      # WorkingDirectory intentionally omitted (or set to /var/lib if you prefer)
      ReadWritePaths     = [ "/var/lib/open-webui" ];
      UMask              = "0077";
      PermissionsStartOnly = true;

      # Stop systemd from creating the private symlink set
      DynamicUser      = mkForce false;
      StateDirectory   = mkForce "";
      RuntimeDirectory = mkForce "";
      CacheDirectory   = mkForce "";
      LogsDirectory    = mkForce "";

      ExecStartPre = [
        "${pkgs.coreutils}/bin/install -d -o open-webui -g open-webui -m 0700 /var/lib/open-webui/tmp"
        "${pkgs.coreutils}/bin/install -d -o open-webui -g open-webui -m 0700 /var/lib/open-webui/cache"
        "${pkgs.coreutils}/bin/install -d -o open-webui -g open-webui -m 0700 /var/lib/open-webui/cache/audio/speech"
        "${pkgs.coreutils}/bin/chown -R open-webui:open-webui /var/lib/open-webui"
      ];
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