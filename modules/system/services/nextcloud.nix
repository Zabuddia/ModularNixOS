{ scheme, host, port, lanPort, streamPort, expose, edgePort }:
{ config, pkgs, lib, collabora ? null, ... }:

let
  infra = import ../../config/hosts.nix;
  thisHost = config.networking.hostName or host;

  defaultPasswordFile = "/etc/nextcloud-user-pass";
  hostRec = lib.findFirst (h: (h.name or null) == thisHost) { } infra.hosts;

  ncUsers =
    let
      list = hostRec.nextcloudUsers or [ ];
      toPair = u: {
        name = u.name;
        value = lib.filterAttrs (_: v: v != null) {
          displayName  = u.displayName or u.name;
          email        = u.email or null;
          isAdmin      = u.isAdmin or false;
          passwordFile = u.passwordFile or defaultPasswordFile;
        };
      };
    in lib.listToAttrs (map toPair list);

  adminPassPath = "/etc/nextcloud-admin-pass";

  homeDir = "/var/lib/nextcloud";
  dataDir = "${homeDir}/data";

  # NixOS 25.11 Nextcloud module expects config.php in:
  #   ${services.nextcloud.datadir}/config/config.php
  configDir = "${dataDir}/config";

  dbDumpPath = "/tmp/nextcloud-db.dump";
  borgRepo   = "/var/backups/nextcloud-borg";

  mkPortSuffix = p:
    if (scheme == "https" && p == 443) || (scheme == "http" && p == 80)
    then ""
    else ":" + toString p;

  visiblePort = if expose == "caddy-wan" then edgePort else lanPort;
  externalUrl = "${scheme}://${host}${mkPortSuffix visiblePort}/";

  mkUserCmd = u: v: ''
    echo ">> Ensuring Nextcloud user: ${u}"

    if nextcloud-occ user:info ${lib.escapeShellArg u} >/dev/null 2>&1; then
      ${lib.optionalString (v ? displayName) "nextcloud-occ user:modify ${lib.escapeShellArg u} displayname ${lib.escapeShellArg v.displayName} || true"}
      ${lib.optionalString (v ? email)       "nextcloud-occ user:modify ${lib.escapeShellArg u} email ${lib.escapeShellArg v.email} || true"}
    else
      if [ -f ${v.passwordFile} ]; then
        export OC_PASS="$(cat ${v.passwordFile})"
      else
        echo "!! ${u}: passwordFile ${v.passwordFile} missing; skipping"
        exit 0
      fi
      nextcloud-occ user:add --password-from-env \
        ${lib.optionalString (v ? displayName) "--display-name ${lib.escapeShellArg v.displayName}"} \
        ${lib.optionalString (v ? email)       "--email ${lib.escapeShellArg v.email}"} \
        ${lib.escapeShellArg u}
    fi

    ${lib.optionalString (v ? isAdmin && v.isAdmin) "nextcloud-occ group:adduser admin ${lib.escapeShellArg u} || true"}
  '';

  ensureScriptBody = lib.concatStrings (lib.mapAttrsToList mkUserCmd ncUsers);

  declaredAdmins = lib.attrNames (lib.filterAttrs (_: v: v.isAdmin or false) ncUsers);

  removeRootIfAdminsExist = ''
    have_admin=0
${lib.concatStringsSep "\n" (map (u: ''
    if nextcloud-occ user:info ${lib.escapeShellArg u} >/dev/null 2>&1; then
      have_admin=1
    fi
'') declaredAdmins)}
    if [ "$have_admin" = "1" ]; then
      if nextcloud-occ user:info root >/dev/null 2>&1; then
        echo ">> Removing legacy 'root' account"
        nextcloud-occ user:delete root || true
      fi
    fi
  '';

  collabUrl =
    if collabora != null && collabora ? url
    then collabora.url
    else "http://localhost:9980";

  # Always use the exact postgres package configured on this machine for pg_dump
  pgDump = "${config.services.postgresql.package}/bin/pg_dump";
in
{
  ############################
  ## Secrets
  ############################
  environment.etc."nextcloud-admin-pass".text = "@ChangePassword";
  environment.etc."nextcloud-user-pass".text  = "@ChangePassword";

  ############################
  ## Filesystem
  ############################
  systemd.tmpfiles.rules = [
    "d ${homeDir}   0750 nextcloud nextcloud -"
    "d ${dataDir}   0750 nextcloud nextcloud -"
    "d ${configDir} 0750 nextcloud nextcloud -"
    "d ${borgRepo}  0700 root root -"
  ];

  ############################
  ## Nextcloud
  ############################
  services.nextcloud = {
    enable = true;

    package = pkgs.nextcloud32;

    hostName = host;
    https = false;

    home = homeDir;
    datadir = dataDir;

    database.createLocally = true;
    config = {
      adminpassFile = adminPassPath;
      dbtype = "pgsql";
      dbname = "nextcloud";
      dbuser = "nextcloud";
      dbhost = "/run/postgresql";
    };

    settings = {
      trusted_domains     = [ host ];
      "overwrite.cli.url" = externalUrl;
      overwritehost       = "${host}${mkPortSuffix visiblePort}";
      overwriteprotocol   = scheme;
      trusted_proxies     = [ "127.0.0.1" ];
      allow_local_remote_servers = true;
    };

    caching = { apcu = true; redis = true; };
    configureRedis = true;

    extraApps = with config.services.nextcloud.package.packages.apps; {
      inherit contacts calendar tasks notes deck forms richdocuments polls;
    };

    extraAppsEnable = true;

    # While you're stabilizing the DB + schema, keep this off.
    autoUpdateApps.enable = false;
  };

  ############################
  ## Nginx
  ############################
  services.nginx.virtualHosts."${host}".listen = [{
    addr = "127.0.0.1";
    port = port;
    ssl = false;
  }];

  ############################
  ## Ensure users
  ############################
  systemd.services.nextcloud-ensure-users = {
    description = "Ensure Nextcloud users exist";
    after = [
      "nextcloud-setup.service"
      "phpfpm-nextcloud.service"
      "postgresql.service"
      "redis-nextcloud.service"
    ];
    requires = [
      "nextcloud-setup.service"
      "postgresql.service"
    ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "nextcloud";
      Group = "nextcloud";
      WorkingDirectory = homeDir;
      Environment = [
        "PATH=${pkgs.php}/bin:${pkgs.coreutils}/bin:/run/current-system/sw/bin:/run/wrappers/bin"
        "NEXTCLOUD_CONFIG_DIR=${configDir}"
      ];
    };
    script = ''
      set -euo pipefail
      ${ensureScriptBody}
      ${removeRootIfAdminsExist}
    '';
  };

  ############################
  ## Collabora wiring (MUST be systemd, not activation)
  ############################
  systemd.services.nextcloud-collabora-config = {
    description = "Configure Nextcloud richdocuments WOPI URL";
    after = [ "nextcloud-setup.service" "postgresql.service" "redis-nextcloud.service" ];
    requires = [ "nextcloud-setup.service" "postgresql.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "nextcloud";
      Group = "nextcloud";
      WorkingDirectory = homeDir;
      Environment = [
        "PATH=${pkgs.php}/bin:${pkgs.coreutils}/bin:/run/current-system/sw/bin:/run/wrappers/bin"
        "NEXTCLOUD_CONFIG_DIR=${configDir}"
      ];
    };
    script = ''
      set -euo pipefail
      current="$(nextcloud-occ -n config:app:get richdocuments wopi_url 2>/dev/null || true)"
      if [ "x$current" != "x${collabUrl}" ]; then
        nextcloud-occ -n -q config:app:set richdocuments wopi_url --value=${lib.escapeShellArg collabUrl} || true
      fi
    '';
  };

  ############################
  ## Borg backup
  ############################
  environment.systemPackages = [ pkgs.borgbackup pkgs.jq ];

  services.borgbackup.jobs.nextcloud = {
    paths = [ dataDir dbDumpPath ];
    repo = borgRepo;
    encryption.mode = "none";
    compression = "zstd,6";
    startAt = "daily";
    prune.keep = {
      within = "7d";
      daily = 14;
      weekly = 8;
      monthly = 12;
    };
    preHook = ''
      set -euo pipefail
      if [ ! -e ${borgRepo}/config ]; then
        ${pkgs.borgbackup}/bin/borg init --encryption=none ${borgRepo}
      fi
      tmp="${dbDumpPath}.new"
      sudo -u postgres ${pgDump} -Fc nextcloud > "$tmp"
      chmod 600 "$tmp"
      mv "$tmp" ${dbDumpPath}
    '';
  };
}