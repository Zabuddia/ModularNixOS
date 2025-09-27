{ scheme, host, port, lanPort, streamPort }:
{ config, pkgs, lib, ... }:

let
  adminPassPath = "/etc/nextcloud-admin-pass";
  externalUrl   = "${scheme}://${host}:${toString port}/";
  homeDir       = "/var/lib/nextcloud";
  dataDir       = "${homeDir}/data";
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
      "overwrite.cli.url"  = externalUrl;
      overwritehost        = "${host}:${toString lanPort}";
      overwriteprotocol    = scheme;  # "http" or "https"
    };

    caching = {
      apcu  = true;
      redis = true;
    };
    configureRedis = true;
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
  # Ensure setup waits for tmpfiles + Postgres
  ############################
  systemd.services.nextcloud-setup = {
    after    = [ "systemd-tmpfiles-setup.service" "systemd-tmpfiles-resetup.service" "postgresql.service" ];
    requires = [ "postgresql.service" "redis.service" ];
    # Optional breathing room for first-run migrations:
    # serviceConfig.TimeoutStartSec = "10min";
  };
}