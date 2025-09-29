{ scheme, host, port, lanPort, streamPort }:
{ config, pkgs, lib, ... }:

let
  # adjust the path to wherever the hosts file lives
  infra = import ../../config/hosts.nix;

  thisHost = config.networking.hostName or host;

  # shared default password file if a user entry doesn't specify one
  defaultPasswordFile = "/etc/nextcloud-user-pass";

  # find this host's record ({} if not found)
  hostRec = lib.findFirst (h: (h.name or null) == thisHost) { } infra.hosts;

  # turn hostRec.nextcloudUsers (list) into the attrset ncUsers our script expects
  # ncUsers.${name} = { displayName, email, isAdmin, passwordFile }
  ncUsers =
    let
      list = hostRec.nextcloudUsers or [ ];
      toPair = u: {
        name = u.name;
        value =
          lib.filterAttrs (_: v: v != null) {
            displayName  = u.displayName or u.name;
            email        = u.email or null;
            isAdmin      = u.isAdmin or false;
            passwordFile = u.passwordFile or defaultPasswordFile;
          };
      };
    in lib.listToAttrs (map toPair list);

  # --- your existing values ---
  adminPassPath = "/etc/nextcloud-admin-pass";
  externalUrl   = "${scheme}://${host}:${toString lanPort}/";
  homeDir       = "/var/lib/nextcloud";
  dataDir       = "${homeDir}/data";
  dbDumpPath    = "/tmp/nextcloud-db.dump";
  borgRepo      = "/var/backups/nextcloud-borg";

  # per-user ensure logic (create if missing; sync metadata; add admin)
  mkUserCmd = u: v: ''
    echo ">> Ensuring Nextcloud user: ${u}"

    if nextcloud-occ user:info ${u} >/dev/null 2>&1; then
      ${lib.optionalString (v ? displayName) "nextcloud-occ user:modify ${u} displayname ${lib.escapeShellArg v.displayName} || true"}
      ${lib.optionalString (v ? email)       "nextcloud-occ user:modify ${u} email ${lib.escapeShellArg v.email} || true"}
    else
      if [ -f ${v.passwordFile} ]; then
        export OC_PASS="$(cat ${v.passwordFile})"
      else
        echo "!! ${u}: passwordFile ${v.passwordFile} missing; skipping"
        continue
      fi
      nextcloud-occ user:add --password-from-env \
        ${lib.optionalString (v ? displayName) "--display-name ${lib.escapeShellArg v.displayName}"} \
        ${lib.optionalString (v ? email)       "--email ${lib.escapeShellArg v.email}"} \
        ${u}
      ${lib.optionalString (v ? displayName) "nextcloud-occ user:modify ${u} displayname ${lib.escapeShellArg v.displayName} || true"}
      ${lib.optionalString (v ? email)       "nextcloud-occ user:modify ${u} email ${lib.escapeShellArg v.email} || true"}
    fi

    ${lib.optionalString (v ? isAdmin && v.isAdmin) "nextcloud-occ group:adduser admin ${u} || true"}
  '';

  ensureScriptBody = lib.concatStrings (lib.mapAttrsToList mkUserCmd ncUsers);

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
  ############################
  ## Files / secrets
  ############################
  environment.etc."nextcloud-admin-pass".text = "@ChangePassword";
  environment.etc."nextcloud-user-pass".text  = "@ChangePassword";

  systemd.tmpfiles.rules = [ "d ${borgRepo} 0700 root root -" ];

  ############################
  ## Nextcloud
  ############################
  services.nextcloud = {
    enable   = true;
    package  = pkgs.nextcloud31;

    hostName = host;
    https    = false;

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
      "overwrite.cli.url" = externalUrl;
      overwritehost       = "${host}:${toString lanPort}";
      overwriteprotocol   = "${scheme}";
      trusted_proxies     = [ "127.0.0.1" ];
    };

    caching = { apcu = true; redis = true; };
    configureRedis = true;

    extraApps = with config.services.nextcloud.package.packages.apps; {
      inherit contacts calendar tasks notes deck forms;
    };
    extraAppsEnable = true;
    autoUpdateApps.enable = true;
  };

  ############################
  ## Nginx (localhost:<port>)
  ############################
  services.nginx.virtualHosts."${host}".listen = [{
    addr = "127.0.0.1"; port = port; ssl = false;
  }];

  ############################
  ## Startup ordering
  ############################
  systemd.services.nextcloud-setup = {
    after    = [ "systemd-tmpfiles-setup.service" "systemd-tmpfiles-resetup.service" "postgresql.service" "redis-nextcloud.service" ];
    requires = [ "postgresql.service" "redis-nextcloud.service" ];
  };

  ############################
  ## Ensure users (from hosts file)
  ############################
  systemd.services.nextcloud-ensure-users = {
    description = "Ensure Nextcloud users exist (create if missing; admin group; retire root)";
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
      ${removeRootIfAdminsExist}
    '';
  };

  ############################
  ## Borg backup
  ############################
  environment.systemPackages = [ pkgs.borgbackup pkgs.jq ];
  services.borgbackup.jobs.nextcloud = {
    paths = [ dataDir dbDumpPath ];
    repo = borgRepo;
    encryption = { mode = "none"; };
    compression = "zstd,6";
    startAt = "daily";
    prune.keep = { within = "7d"; daily = 14; weekly = 8; monthly = 12; };
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
    postHook = '' echo "Borg backup completed at $(date)" '';
  };
}