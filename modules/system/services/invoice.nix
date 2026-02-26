{ scheme, host, port, lanPort, streamPort ? null, expose ? null, edgePort ? null }:

{ config, pkgs, lib, ... }:
let
  toS = builtins.toString;

  stateDir   = "/var/lib/invoiceninja";
  publicDir  = "${stateDir}/public";
  storageDir = "${stateDir}/storage";
  dbDir      = "${stateDir}/mysql";
  redisDir   = "${stateDir}/redis";

  extPort =
    if expose == "caddy-wan" then edgePort else lanPort;

  extPortSuffix =
    if extPort == null || extPort == 80 || extPort == 443 then "" else ":${toS extPort}";

  externalURL = "${scheme}://${host}${extPortSuffix}";

  envFile = "/etc/invoiceninja/.env";

  nginxConf = pkgs.writeText "invoiceninja-nginx.conf" ''
    server {
      listen 80;
      server_name _;

      root /var/www/html/public;
      index index.php;

      client_max_body_size 64m;

      # Serve static assets directly (avoid routing them to PHP)
      location ~* \.(?:css|js|mjs|map|png|jpg|jpeg|gif|svg|ico|webp|woff2?|ttf|otf)$ {
        try_files $uri =404;
        access_log off;
        expires 30d;
        add_header Cache-Control "public, max-age=2592000, immutable";
      }

      location / {
        try_files $uri $uri/ /index.php?$query_string;
      }

      location ~ \.php$ {
        include /etc/nginx/fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;

        # Forward original scheme/host/port from Caddy
        fastcgi_param HTTP_X_FORWARDED_PROTO $http_x_forwarded_proto;
        fastcgi_param HTTP_X_FORWARDED_HOST  $http_x_forwarded_host;
        fastcgi_param HTTP_X_FORWARDED_PORT  $http_x_forwarded_port;

        fastcgi_pass app:9000;
        fastcgi_read_timeout 600;

        fastcgi_buffers 16 16k;
        fastcgi_buffer_size 32k;
      }
    }
  '';
in
{
  systemd.tmpfiles.rules = [
    "d ${stateDir}   0755 root root - -"
    "d ${publicDir}  0755 root root - -"

    "d ${storageDir} 0775 root root - -"
    "d ${storageDir}/logs               0775 root root - -"
    "d ${storageDir}/framework          0775 root root - -"
    "d ${storageDir}/framework/cache    0775 root root - -"
    "d ${storageDir}/framework/sessions 0775 root root - -"
    "d ${storageDir}/framework/views    0775 root root - -"

    "d ${dbDir}      0755 root root - -"
    "d ${redisDir}   0755 root root - -"
    "d /etc/invoiceninja 0750 root root - -"
  ];

  virtualisation.podman.enable = true;
  virtualisation.oci-containers.backend = "podman";

  systemd.services.podman-network-invoiceninja = {
    wantedBy = [ "multi-user.target" ];
    before = [
      "podman-mysql.service"
      "podman-redis.service"
      "podman-app.service"
      "podman-nginx.service"
    ];
    serviceConfig.Type = "oneshot";
    script = ''
      ${pkgs.podman}/bin/podman network inspect invoiceninja >/dev/null 2>&1 || \
        ${pkgs.podman}/bin/podman network create invoiceninja
    '';
  };

  systemd.services.invoiceninja-storage-perms = {
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-tmpfiles-setup.service" ];
    before = [ "podman-app.service" ];
    serviceConfig.Type = "oneshot";
    script = ''
      ${pkgs.coreutils}/bin/mkdir -p \
        ${storageDir}/logs \
        ${storageDir}/framework/cache \
        ${storageDir}/framework/sessions \
        ${storageDir}/framework/views

      ${pkgs.coreutils}/bin/chmod -R 0775 ${storageDir}
      ${pkgs.coreutils}/bin/mkdir -p ${publicDir}
    '';
  };

  virtualisation.oci-containers.containers = {
    mysql = {
      image = "mysql:8";
      autoStart = true;
      extraOptions = [ "--pull=newer" "--network=invoiceninja" "--network-alias=mysql" ];
      volumes = [ "${dbDir}:/var/lib/mysql" ];
      environmentFiles = [ envFile ];
      environment.TZ = config.time.timeZone or "UTC";
    };

    redis = {
      image = "redis:alpine";
      autoStart = true;
      extraOptions = [ "--pull=newer" "--network=invoiceninja" "--network-alias=redis" ];
      volumes = [ "${redisDir}:/data" ];
    };

    # PHP-FPM app
    app = {
      image = "invoiceninja/invoiceninja-debian:latest";
      autoStart = true;
      extraOptions = [ "--pull=newer" "--network=invoiceninja" "--network-alias=app" ];
      dependsOn = [ "mysql" "redis" ];

      # IMPORTANT: mount public RW so the container can populate assets into it
      volumes = [
        "${publicDir}:/var/www/html/public"
        "${storageDir}:/var/www/html/storage"
      ];

      environmentFiles = [ envFile ];
      environment = {
        APP_URL = externalURL;
        TRUSTED_PROXIES = "*";
        TZ = config.time.timeZone or "UTC";
      };
    };

    # Web server
    nginx = {
      image = "nginx:alpine";
      autoStart = true;
      extraOptions = [ "--pull=newer" "--network=invoiceninja" "--network-alias=nginx" ];
      dependsOn = [ "app" ];

      # Expose nginx to host (Caddy reverse proxies to this)
      ports = [ "${toS port}:80" ];

      volumes = [
        "${publicDir}:/var/www/html/public:ro"
        "${storageDir}:/var/www/html/storage:ro"
        "${nginxConf}:/etc/nginx/conf.d/default.conf:ro"
      ];
    };
  };
}