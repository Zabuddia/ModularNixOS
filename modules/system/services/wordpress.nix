{ scheme, host, port, lanPort, streamPort, expose, edgePort }:

{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf replaceStrings;
  extPort =
    if expose == "caddy-wan" then edgePort else lanPort;

  extPortSuffix =
    if extPort == null || extPort == 80 || extPort == 443 then "" else ":${toString extPort}";

  externalURL = "${scheme}://${host}${extPortSuffix}";
  slug = replaceStrings [ "." "-" ] [ "_" "_" ] host;
  wpStateDir = "/var/lib/wordpress/${host}";
in
{
  services.mariadb.enable = true;

  services.wordpress = {
    enable = true;
    webserver = "nginx";

    sites."${host}" = {
      package = pkgs.wordpress_6_8;

      # Minimal wp-config constants so it knows its public URL behind Caddy.
      settings = {
        WP_HOME   = externalURL;
        WP_SITEURL = externalURL;
        WP_DEBUG = false;
      };

      # Create a local DB + user (simple, one-file password we generate below).
      database = {
        createLocally = true;
        host = "localhost";
        name = "wp_${slug}";
        user = "wp_${slug}";
        passwordFile = "${wpStateDir}/db-password";
      };

      # Media uploads location.
      uploadsDir = "${wpStateDir}/uploads";

      # Bind nginx only on loopback at the requested port.
      virtualHost.listen = [
        { ip = "127.0.0.1"; port = port; ssl = false; }
      ];
      virtualHost.hostName = host;
    };
  };

  # Ensure state dir + random DB password exist (kept tiny & local).
  systemd.tmpfiles.rules = [
    "d ${wpStateDir} 0700 root root - -"
  ];
  system.activationScripts."wp-${slug}-secrets" = {
    text = ''
      set -eu
      install -d -m 0700 -o root -g root ${wpStateDir}
      if [ ! -f ${wpStateDir}/db-password ]; then
        tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32 > ${wpStateDir}/db-password
        chmod 600 ${wpStateDir}/db-password
      fi
    '';
  };
}