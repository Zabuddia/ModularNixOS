# modules/system/services/nextcloud.nix
{ scheme, host, port }:
{ config, pkgs, lib, ... }:

let
  adminPassPath = "/etc/nextcloud-admin-pass";
  externalUrl   = "${scheme}://${host}:${toString port}/";
in
{
  # Default admin password file (user is "root")
  environment.etc."nextcloud-admin-pass".text = "@RandomPassword";

  services.nextcloud = {
    enable  = true;
    package = pkgs.nextcloud31;
    hostName = host;
    https = false;  # TLS handled by your proxy

    config = {
      adminpassFile = adminPassPath;
      dbtype        = "sqlite";
    };

    settings = {
      trusted_domains    = [ host ];
      "overwrite.cli.url" = externalUrl;
      overwritehost      = "${host}:${toString port}";
      overwriteprotocol  = scheme;
    };

    nginx.listen = [{
      addr = "127.0.0.1";
      port = port;
      ssl  = false;
    }];
  };
}