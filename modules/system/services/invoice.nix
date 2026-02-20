{ scheme, host, port, lanPort, streamPort ? null, expose ? null, edgePort ? null }:

{ config, pkgs, lib, ... }:
let
  toS = builtins.toString;

  stateDir   = "/var/lib/invoiceninja";
  publicDir  = "${stateDir}/public";
  storageDir = "${stateDir}/storage";
  dbDir      = "${stateDir}/mysql";
  redisDir   = "${stateDir}/redis";

  # External URL (what Invoice Ninja should use in links, logos, PDFs, etc.)
  extPort =
    if expose == "caddy-wan" then edgePort else lanPort;

  extPortSuffix =
    if extPort == null || extPort == 80 || extPort == 443 then "" else ":${toS extPort}";

  externalURL = "${scheme}://${host}${extPortSuffix}";

  # Debian dockerfiles expect a .env file (APP_KEY, DB_PASSWORD, etc.)
  envFile = "/etc/invoiceninja/.env";

  nginxConf = pkgs.writeText "invoiceninja-nginx.conf" ''
    server {
      listen 80;
      server_name _;

      root /var/www/html/public;
      index index.php;

      client_max_body_size 64m;

      location / {
        try_files $uri $uri/ /index.php?$query_string;
      }

      location ~ \.php$ {
        include /etc/nginx/fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_pass app:9000;
        fastcgi_read_timeout 600;

        fastcgi_buffers 16 16k;
        fastcgi_buffer_size 32k;
      }
    }
  '';
in
{
  ############################################
  # Directories / permissions
  #
  # IMPORTANT: do NOT force storage to 0755.
  # Keep it group-writable so the app can create logs/cache/sessions.
  ############################################
  systemd.tmpfiles.rules = [
    "d ${stateDir}   0755 root root - -"
    "d ${publicDir}  0755 root root - -"

    # writable state for Laravel
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

  ############################################
  # Podman + OCI containers
  ############################################
  virtualisation.podman.enable = true;
  virtualisation.oci-containers.backend = "podman";

  # Create the podman network (oci-containers will not auto-create it)
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

  ############################################
  # Ensure storage perms BEFORE app starts
  #
  # We avoid chown here because podman/userns/idmapped mounts can make host UID
  # look "UNKNOWN". What matters is: directory exists + mode allows writes.
  ############################################
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
    '';
  };

  ############################################
  # Containers
  ############################################
  virtualisation.oci-containers.containers = {
    mysql = {
      image = "mysql:8";
      autoStart = true;

      extraOptions = [
        "--pull=newer"
        "--network=invoiceninja"
        "--network-alias=mysql"
      ];

      volumes = [
        "${dbDir}:/var/lib/mysql"
      ];

      environmentFiles = [ envFile ];
      environment = {
        TZ = config.time.timeZone or "UTC";
      };
    };

    redis = {
      image = "redis:alpine";
      autoStart = true;

      extraOptions = [
        "--pull=newer"
        "--network=invoiceninja"
        "--network-alias=redis"
      ];

      volumes = [
        "${redisDir}:/data"
      ];
    };

    # Debian “app” container (includes Chrome etc.)
    app = {
      image = "invoiceninja/invoiceninja-debian:latest";
      autoStart = true;

      extraOptions = [
        "--pull=newer"
        "--network=invoiceninja"
        "--network-alias=app"
      ];

      dependsOn = [ "mysql" "redis" ];

      # NOTE: removed :U to avoid ownership/idmap weirdness
      volumes = [
        "${publicDir}:/var/www/html/public"
        "${storageDir}:/var/www/html/storage"
      ];

      environmentFiles = [ envFile ];
      environment = {
        APP_URL = externalURL;
        TZ = config.time.timeZone or "UTC";
      };
    };

    nginx = {
      image = "nginx:alpine";
      autoStart = true;

      extraOptions = [
        "--pull=newer"
        "--network=invoiceninja"
        "--network-alias=nginx"
      ];

      dependsOn = [ "app" ];

      ports = [ "${toS port}:80" ];

      # NOTE: removed :U here too
      volumes = [
        "${publicDir}:/var/www/html/public:ro"
        "${storageDir}:/var/www/html/storage:ro"
        "${nginxConf}:/etc/nginx/conf.d/default.conf:ro"
      ];
    };
  };
}