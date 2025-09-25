{ scheme, host, port, lanPort, streamPort }:
{ config, pkgs, lib, ... }:

let
  adminPassPath = "/etc/nextcloud-admin-pass";
  externalUrl   = "${scheme}://${host}:${toString port}/";
in
{
  # Default admin password file (user is "root")
  environment.etc."nextcloud-admin-pass".text = "@RandomPassword";

  services.nextcloud = {
    enable   = true;
    package  = pkgs.nextcloud31;
    hostName = host;     # vhost name (no port here)
    https    = false;    # TLS terminated by your expose layer

    config = {
      adminpassFile = adminPassPath;
      dbtype        = "sqlite";
    };

    settings = {
      trusted_domains      = [ host ];
      "overwrite.cli.url"  = externalUrl;
      overwritehost        = "${host}:${toString lanPort}";
      overwriteprotocol    = scheme;  # "http" or "https"
    };
  };

  # Make Nextcloud's nginx vhost listen only on localhost:<port>
  services.nginx.virtualHosts."${host}".listen = [{
    addr = "127.0.0.1";
    port = port;
    ssl  = false;
  }];
}