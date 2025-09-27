{ scheme, host, port, lanPort, streamPort }:
{ config, pkgs, lib, ... }:

let
  adminPassPath = "/etc/nextcloud-admin-pass";
  externalUrl   = "${scheme}://${host}:${toString port}/";
in
{
  # Admin password for the "root" Nextcloud user (swap to sops/agenix later)
  environment.etc."nextcloud-admin-pass".text = "@RandomPassword";

  services.nextcloud = {
    enable   = true;
    package  = pkgs.nextcloud31;
    hostName = host;     # vhost name only (no port)
    https    = false;    # TLS handled by your edge proxy

    # Use local PostgreSQL over UNIX socket (no password needed)
    database.createLocally = true;
    config = {
      adminpassFile = adminPassPath;
      dbtype        = "pgsql";
      dbname        = "nextcloud";
      dbuser        = "nextcloud";
      # no dbpassFile, no dbhost → peer auth via /run/postgresql
    };

    # Fast & safe defaults: APCu (local cache) + Redis (locking/cache)
    caching = {
      apcu  = true;
      redis = true;
    };
    configureRedis = true;

    # Keep your existing external/overwrite settings for proxying
    settings = {
      trusted_domains     = [ host ];
      "overwrite.cli.url" = externalUrl;
      overwritehost       = "${host}:${toString lanPort}";
      overwriteprotocol   = scheme;  # "http" or "https"
    };

    # Optional: bump if you plan to upload large files
    # maxUploadSize = "4G";
  };

  # Bind Nextcloud’s nginx vhost only on localhost:<port>
  services.nginx.virtualHosts."${host}".listen = [{
    addr = "127.0.0.1";
    port = port;
    ssl  = false;
  }];
}