{ scheme, host, port }:

{ config, pkgs, lib, ... }:
{
  systemd.services.pyhttp = {
    description = "Python simple HTTP server";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python -m http.server ${toString port}";
      WorkingDirectory = "/tmp"; # serve files from /tmp
    };
  };
}