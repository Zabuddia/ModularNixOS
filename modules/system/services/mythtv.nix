{ scheme, host, port, lanPort, streamPort, expose, edgePort }:

{ config, pkgs, lib, ... }:
let
  dbName = "mythconverg";
  dbUser = "mythtv";
  dbPass = "mythtv";           # change me later
  mythUser = "mythtv";
  mythHome = "/var/lib/mythtv";  # will hold ~/.mythtv/config.xml
in
{
  ############################
  # Packages & user
  ############################
  environment.systemPackages = [ pkgs.mythtv ]; # gives mythtv-setup, mythbackend, etc.

  users.groups.${mythUser} = {};
  users.users.${mythUser} = {
    isSystemUser = true;
    home = mythHome;
    group = mythUser;
    description = "MythTV backend user";
    extraGroups = [ "video" ]; # access to /dev/dvb/*
  };

  ############################
  # MariaDB for MythTV
  ############################
  services.mysql = {
    enable = true;                    # MariaDB
    package = pkgs.mariadb;
    ensureDatabases = [ dbName ];
    ensureUsers = [{
      name = dbUser;
      ensurePermissions = { "${dbName}.*" = "ALL PRIVILEGES"; };
      # For initial setup we use a simple password; rotate later.
      # On first activation we'll set it via an init script:
    }];
    # Create user + set password only if not exists
    initialScript = pkgs.writeText "init-mythtv.sql" ''
      CREATE USER IF NOT EXISTS '${dbUser}'@'localhost' IDENTIFIED BY '${dbPass}';
      GRANT ALL PRIVILEGES ON ${dbName}.* TO '${dbUser}'@'localhost';
      FLUSH PRIVILEGES;
    '';
  };

  ############################
  # Config file for mythbackend/mythtv-setup
  ############################
  systemd.tmpfiles.rules = [
    "d ${mythHome} 0750 ${mythUser} ${mythUser} -"
    "d ${mythHome}/.mythtv 0750 ${mythUser} ${mythUser} -"
    "d /var/log/mythtv 0750 ${mythUser} ${mythUser} -"
  ];

  system.activationScripts.mythtvConfig = {
    text = ''
      set -eu
      conf="${mythHome}/.mythtv/config.xml"
      install -d -m 0750 -o ${mythUser} -g ${mythUser} "$(dirname "$conf")"
      cat > "$conf" <<'EOF'
<Configuration>
  <Database>
    <PingHost>1</PingHost>
    <Host>localhost</Host>
    <UserName>${dbUser}</UserName>
    <Password>${dbPass}</Password>
    <Name>${dbName}</Name>
    <Port>3306</Port>
    <Type>QMYSQL</Type>
  </Database>
</Configuration>
EOF
      chown ${mythUser}:${mythUser} "$conf"
      chmod 0640 "$conf"
    '';
  };

  ############################
  # mythbackend service (simple)
  ############################
  systemd.services.mythbackend = {
    description = "MythTV Backend";
    wants = [ "mysql.service" ];
    after  = [ "mysql.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      User = mythUser;
      Group = mythUser;
      WorkingDirectory = mythHome;
      ExecStart = "${pkgs.mythtv}/bin/mythbackend --logpath /var/log/mythtv";
      Restart = "on-failure";
      RestartSec = 5;
      # Let it access DVB devices
      DeviceAllow = [ "/dev/dvb/* rw" ];
    };
  };
}