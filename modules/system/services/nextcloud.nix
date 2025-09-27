{ scheme, host, port, lanPort, streamPort }:
{ config, pkgs, lib, ... }:

let
  adminPassPath = "/etc/nextcloud-admin-pass";
  # Use the PUBLIC side for link generation (not the internal :port)
  externalUrl   = "${scheme}://${host}:${toString lanPort}/";
  homeDir       = "/var/lib/nextcloud";
  dataDir       = "${homeDir}/data";

  # ---- Borg backup bits ----
  # Write DB dump into the job's writable private /tmp (not /var, which is RO in the unit)
  dbDumpPath    = "/tmp/nextcloud-db.dump";              # pg_dump -Fc file (ephemeral)
  borgRepo      = "/var/backups/nextcloud-borg";         # local repo (can be ssh:// later)
in
{
  # Default admin password file (Nextcloud admin user is "root")
  environment.etc."nextcloud-admin-pass".text = "@RandomPassword";

  ############################
  # Files/ownership (declarative)
  ############################
  systemd.tmpfiles.rules = [
    # Create if missing
    "d ${homeDir}        0750 nextcloud nextcloud -"
    "d ${dataDir}        0750 nextcloud nextcloud -"
    "d ${homeDir}/config 0750 nextcloud nextcloud -"
    # Fix ownership/perm if paths already exist (from past runs)
    "z ${homeDir}        0750 nextcloud nextcloud -"
    "z ${dataDir}        0750 nextcloud nextcloud -"
    "z ${homeDir}/config 0750 nextcloud nextcloud -"

    # Borg repo directory (root-owned). Only the repo needs to be writable by the unit.
    "d ${borgRepo}        0700 root root -"
  ];

  ############################
  # Nextcloud
  ############################
  services.nextcloud = {
    enable   = true;
    package  = pkgs.nextcloud31;
    hostName = host;   # FQDN only (no port here)
    https    = false;  # TLS terminated by your expose layer (Caddy/Tailscale/etc.)

    # Keep paths explicit so Nextcloud never guesses under data/
    home    = homeDir;
    datadir = dataDir;

    # Local PostgreSQL via UNIX socket; NixOS provisions DB+role (no password needed)
    database.createLocally = true;
    config = {
      adminpassFile = adminPassPath;
      dbtype        = "pgsql";
      dbname        = "nextcloud";
      dbuser        = "nextcloud";
      # no dbpassFile, no dbhost -> peer auth over /run/postgresql
    };

    settings = {
      trusted_domains      = [ host ];
      "overwrite.cli.url"  = externalUrl;                     # <- now public URL
      overwritehost        = "${host}:${toString lanPort}";   # <- public host:port
      overwriteprotocol    = "${scheme}";                     # "http" or "https"
      trusted_proxies      = [ "127.0.0.1" ];
    };

    caching = {
      apcu  = true;
      redis = true;
    };
    configureRedis = true;

    # Apps come from the *same* version you chose above
    extraApps = with config.services.nextcloud.package.packages.apps; {
      inherit contacts calendar tasks notes deck forms;
      # Example for pinning an app not in nixpkgs:
      # passwords = pkgs.fetchNextcloudApp {
      #   appName    = "passwords";
      #   appVersion = "2025.9.0";
      #   url        = "https://git.mdns.eu/api/v4/projects/45/packages/generic/passwords/2025.9.0/passwords.tar.gz";
      #   sha256     = "1xi4dxrmnhki29z620jd98apjf7kssmw5bjschb5chjvb1z6nrqb";
      #   license    = "agpl3Plus";
      # };
    };

    extraAppsEnable = true;  # auto-enable on startup
  };

  ############################
  # Nginx: only listen on localhost:<port>
  ############################
  services.nginx.virtualHosts."${host}".listen = [{
    addr = "127.0.0.1";
    port = port;
    ssl  = false;
  }];

  ############################
  # Ensure setup waits for tmpfiles + Postgres (+ Redis)
  ############################
  systemd.services.nextcloud-setup = {
    after    = [
      "systemd-tmpfiles-setup.service"
      "systemd-tmpfiles-resetup.service"
      "postgresql.service"
      "redis.service"
    ];
    requires = [ "postgresql.service" "redis.service" ];
    # serviceConfig.TimeoutStartSec = "10min";
  };

  ############################
  # Borg backup (files + Postgres dump)
  ############################
  # 1) Password for the repo (change it!)
  environment.etc."nextcloud-borg-pass" = {
    text = "@ChangeThisToAStrongPassphrase";
    mode = "0600";
    user = "root";
    group = "root";
  };

  # 2) Optional: borg CLI available on the box
  environment.systemPackages = [ pkgs.borgbackup ];

  # 3) Nightly job: dump DB then archive files + dump to the repo, with pruning
  services.borgbackup.jobs.nextcloud = {
    paths = [
      dataDir
      dbDumpPath
    ];
    repo = borgRepo;                 # switch to ssh://user@host:/path when ready
    encryption = {
      mode = "repokey-blake2";
      passCommand = "cat /etc/nextcloud-borg-pass";
    };
    compression = "zstd,6";
    startAt = "daily";

    # Keep policy (tweak to taste)
    prune.keep = {
      within  = "7d";  # all backups within last 7 days
      daily   = 14;
      weekly  = 8;
      monthly = 12;
    };

    # Run pg_dump just before creating the archive;
    # also auto-init the repo on first run so you don't have to do it manually.
    preHook = ''
      set -euo pipefail

      export BORG_PASSPHRASE="$(${pkgs.coreutils}/bin/cat /etc/nextcloud-borg-pass)"
      if [ ! -e ${borgRepo}/config ]; then
        ${pkgs.borgbackup}/bin/borg init --encryption repokey-blake2 ${borgRepo}
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