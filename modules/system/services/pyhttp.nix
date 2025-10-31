{ scheme, host, port, lanPort, streamPort, expose, edgePort }:

{ config, pkgs, lib, ... }:
{
  systemd.services.pyhttp = {
    description = "Python simple HTTP server";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      # Create /var/lib/pyhttp automatically
      StateDirectory = "pyhttp";

      WorkingDirectory = "%S/pyhttp"; # expands to /var/lib/pyhttp
      ExecStart = "${pkgs.python3}/bin/python -m http.server ${toString port}";
    };
  };
}