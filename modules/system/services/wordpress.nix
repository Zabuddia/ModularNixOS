{ scheme, host, port, lanPort, streamPort, expose, edgePort }:

{ config, lib, pkgs, unstablePkgs, ... }:
let
  extPort =
    if expose == "caddy-wan" then edgePort else lanPort;

  extPortSuffix =
    if extPort == null || extPort == 80 || extPort == 443
    then "" else ":${toString extPort}";

  externalURL = "${scheme}://${host}${extPortSuffix}";
in
{
  services.nginx.enable = true;

  services.wordpress.webserver = "nginx";
  services.wordpress.sites."${host}" = {
    package = unstablePkgs.wordpress;

    settings = {
      WP_HOME         = externalURL;
      WP_SITEURL      = externalURL;
      FORCE_SSL_ADMIN = true;
    };

    # HTTPS hint + writable plugin/uploads/temp without changing WP_CONTENT_DIR
    extraConfig = ''
      $_SERVER["HTTPS"] = "on";
      define('FS_METHOD', 'direct');

      // Put plugins in a writable place and tell WP their URL
      define('WP_PLUGIN_DIR', '/var/lib/wordpress/${host}/wp-content/plugins');
      define('WP_PLUGIN_URL', '${externalURL}/wp-content/plugins');

      // Put uploads in a writable place (URL will remain /wp-content/uploads)
      define('UPLOADS', 'wp-content/uploads');

      // Writable temp/upgrade dirs
      define('WP_TEMP_DIR',    '/var/lib/wordpress/${host}/tmp');
    '';

    database = {
      createLocally = true;
      user   = "wordpress";
      name   = "wordpress";
      socket = "/run/mysqld/mysqld.sock";
    };
  };

  # Bind WordPress vhost on loopback; your Caddy can reverse-proxy to it.
  services.nginx.virtualHosts."${host}" = {
    listen = [{
      addr = "127.0.0.1";
      port = port;
      ssl  = false;
    }];

    # Serve only the mutable subpaths from /var/lib; leave themes to the package.
    extraConfig = ''
      client_max_body_size 128m;
      proxy_read_timeout 300s;
      proxy_send_timeout 300s;

      location ^~ /wp-content/plugins/ {
        alias /var/lib/wordpress/${host}/wp-content/plugins/;
      }
      location ^~ /wp-content/uploads/ {
        alias /var/lib/wordpress/${host}/wp-content/uploads/;
      }
      location ^~ /wp-content/upgrade/ {
        alias /var/lib/wordpress/${host}/wp-content/upgrade/;
      }
      # (Do NOT alias /wp-content/themes/ so packaged themes keep working)
    '';
  };

  # Ensure the writable tree exists & is owned by the PHP-FPM user/group
  systemd.tmpfiles.rules = [
    "d /var/lib/wordpress/${host}                    0775 wordpress nginx - -"
    "d /var/lib/wordpress/${host}/wp-content         0775 wordpress nginx - -"
    "d /var/lib/wordpress/${host}/wp-content/plugins 0775 wordpress nginx - -"
    "d /var/lib/wordpress/${host}/wp-content/uploads 0775 wordpress nginx - -"
    "d /var/lib/wordpress/${host}/wp-content/upgrade 0775 wordpress nginx - -"
    "d /var/lib/wordpress/${host}/tmp                0775 wordpress nginx - -"
  ];
}