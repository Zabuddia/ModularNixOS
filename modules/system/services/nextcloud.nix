{ scheme, host, port, lanPort, streamPort }:
{ config, pkgs, lib, ... }:

let
  adminPassPath = "/etc/nextcloud-admin-pass";
  # Use the PUBLIC side for link generation (not the internal :port)
  externalUrl   = "${scheme}://${host}:${toString lanPort}/";
  homeDir       = "/var/lib/nextcloud";
  dataDir       = "${homeDir}/data";

  # ---- Borg backup bits ----
  dbDumpPath    = "/tmp/nextcloud-db.dump";      # pg_dump -Fc file (ephemeral)
  borgRepo      = "/var/backups/nextcloud-borg"; # local repo (can be ssh:// later)

  # ---- Declarative users for our idempotent ensure service ----
  # 'passwordFile' is used only on first creation.
  # 'displayName', 'email', 'isAdmin' are optional and synced if provided.
  ncUsers = {
    buddia = {
      passwordFile = "/etc/nextcloud-user-pass";
      displayName  = "Alan Fife";
      email        = "fife.alan@protonmail.com";
      isAdmin      = true;
    };
    # Examples:
    # user1 = { passwordFile = "/etc/nextcloud-user-pass"; email = "user1@example.com"; };
    # user2 = { passwordFile = "/etc/nextcloud-user-pass"; email = "user2@example.com"; isAdmin = true; };
  };

  # Build per-user ensure steps (create if missing; sync metadata; add to admin group if requested)
  mkUserCmd = u: v: ''
    echo ">> Ensuring Nextcloud user: ${u}"

    if nextcloud-occ user:info ${u} >/dev/null 2>&1; then
      # Already exists: best-effort metadata sync
      ${lib.optionalString (v ? displayName) "nextcloud-occ user:modify ${u} displayname ${lib.escapeShellArg v.displayName} || true"}
      ${lib.optionalString (v ? email)       "nextcloud-occ user:modify ${u} email ${lib.escapeShellArg v.email} || true"}
    else
      # Prepare password for creation
      ${lib.optionalString (v ? passwordFile) ''
        if [ -f ${v.passwordFile} ]; then
          export OC_PASS="$(cat ${v.passwordFile})"
        else
          echo "!! ${u}: passwordFile ${v.passwordFile} missing; skipping"
          continue
        fi
      ''}

      # Create WITH email at creation time (as requested)
      nextcloud-occ user:add --password-from-env \
        ${lib.optionalString (v ? displayName) "--display-name ${lib.escapeShellArg v.displayName}"} \
        ${lib.optionalString (v ? email)       "--email ${lib.escapeShellArg v.email}"} \
        ${u}

      # After creation, sync metadata again (non-fatal)
      ${lib.optionalString (v ? displayName) "nextcloud-occ user:modify ${u} displayname ${lib.escapeShellArg v.displayName} || true"}
      ${lib.optionalString (v ? email)       "nextcloud-occ user:modify ${u} email ${lib.escapeShellArg v.email} || true"}
    fi

    # Ensure admin membership if requested (non-fatal)
    ${lib.optionalString (v ? isAdmin && v.isAdmin) "nextcloud-occ group:adduser admin ${u} || true"}
  '';

  ensureScriptBody = lib.concatStrings (lib.mapAttrsToList mkUserCmd ncUsers);

  # After-step that removes 'root' iff at least one declared admin exists (and actually present)
  declaredAdmins = lib.attrNames (lib.filterAttrs (_: v: (v ? isAdmin) && v.isAdmin) ncUsers);
  removeRootIfAdminsExist = ''
    have_admin=0
${lib.concatStringsSep "\n" (map (u: ''
    if nextcloud-occ user:info ${u} >/dev/null 2>&1; then
      have_admin=1
    fi
'') declaredAdmins)}
    if [ "$have_admin" = "1" ]; then
      if nextcloud-occ user:info root >/dev/null 2>&1; then
        echo ">> Removing legacy 'root' account (admins present)"
        nextcloud-occ user:delete root || true
      fi
    else
      echo ">> No declared admins present yet; keeping 'root' for safety"
    fi
  '';
in
{
  ############################################
  ## Files / secrets
  ############################################
  environment.etc."nextcloud-admin-pass".text = "@ChangePassword";
  environment.etc."nextcloud-user-pass".text  = "@ChangePassword";

  systemd.tmpfiles.rules = [
    "d ${borgRepo} 0700 root root -"
  ];

  ############################################
  ## Nextcloud
  ############################################
  services.nextcloud = {
    enable   = true;
    package  = pkgs.nextcloud31;

    hostName = host;   # FQDN only (no port here)
    https    = false;  # TLS terminated by your edge (Caddy/Tailscale/etc.)

    home    = homeDir;
    datadir = dataDir;

    database.createLocally = true;
    config = {
      adminpassFile = adminPassPath;
      dbtype        = "pgsql";
      dbname        = "nextcloud";
      dbuser        = "nextcloud";
    };

    settings = {
      trusted_domains     = [ host ];
      "overwrite.cli.url" = externalUrl;                     # public URL for links
      overwritehost       = "${host}:${toString lanPort}";   # public host:port
      overwriteprotocol   = "${scheme}";                     # "http" or "https"
      trusted_proxies     = [ "127.0.0.1" ];
    };

    caching = {
      apcu  = true;
      redis = true;
    };
    configureRedis = true;

    extraApps = with config.services.nextcloud.package.packages.apps; {
      inherit contacts calendar tasks notes deck forms;
    };
    extraAppsEnable = true;
    autoUpdateApps.enable = true;
  };

  ############################################
  ## Nginx: only listen on localhost:<port>
  ############################################
  services.nginx.virtualHosts."${host}".listen = [{
    addr = "127.0.0.1";
    port = port;
    ssl  = false;
  }];

  ############################################
  ## Startup ordering (Postgres + Redis)
  ############################################
  systemd.services.nextcloud-setup = {
    after    = [
      "systemd-tmpfiles-setup.service"
      "systemd-tmpfiles-resetup.service"
      "postgresql.service"
      "redis-nextcloud.service"
    ];
    requires = [ "postgresql.service" "redis-nextcloud.service" ];
  };

  ############################################
  ## Ensure users (idempotent, runs after setup)
  ############################################
  systemd.services.nextcloud-ensure-users = {
    description = "Ensure Nextcloud users exist (create if missing; sync metadata; admin group; retire root)";
    after    = [ "nextcloud-setup.service" "phpfpm-nextcloud.service" "redis-nextcloud.service" "postgresql.service" ];
    requires = [ "nextcloud-setup.service" "phpfpm-nextcloud.service" "redis-nextcloud.service" "postgresql.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      User = "nextcloud";
      Group = "nextcloud";
      WorkingDirectory = "/var/lib/nextcloud";
      Environment = [
        "PATH=${pkgs.php}/bin:${pkgs.coreutils}/bin:${pkgs.jq}/bin:/run/current-system/sw/bin:/run/wrappers/bin"
        "NEXTCLOUD_CONFIG_DIR=/var/lib/nextcloud/config"
      ];
    };

    script = ''
      set -euo pipefail
      ${ensureScriptBody}

      # If any declared admin exists, remove legacy 'root' safely.
      ${removeRootIfAdminsExist}
    '';
  };

  ############################################
  ## Borg backup (files + Postgres dump)
  ############################################
  environment.systemPackages = [ pkgs.borgbackup pkgs.jq ];

  services.borgbackup.jobs.nextcloud = {
    paths = [
      dataDir
      dbDumpPath
    ];
    repo = borgRepo;
    encryption = { mode = "none"; };
    compression = "zstd,6";
    startAt = "daily";

  prune.keep = {
      within  = "7d";
      daily   = 14;
      weekly  = 8;
      monthly = 12;
    };

    preHook = ''
      set -euo pipefail
      if [ ! -e ${borgRepo}/config ]; then
        ${pkgs.borgbackup}/bin/borg init --encryption=none ${borgRepo}
      fi
      tmp="${dbDumpPath}.new"
      ${pkgs.sudo}/bin/sudo -u postgres ${pkgs.postgresql_16}/bin/pg_dump -Fc nextcloud > "$tmp"
      chmod 600 "$tmp"
      mv "$tmp" ${dbDumpPath}
    '';

    postHook = ''
      echo "Borg backup completed at $(date)"
    '';
  };
}