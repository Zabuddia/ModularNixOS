{ pkgs, ... }:
{
  services.tailscale = {
    enable = true;
    extraUpFlags = [ "--accept-routes" ];
  };

  environment.systemPackages = with pkgs; [ tailscale-systray ];

  systemd.user.services.tailscale-systray = {
    description = "Tailscale Systray";
    wantedBy = [ "default.target" ];
    after = [ "dbus.service" ];
    serviceConfig = {
      ExecStart = "${pkgs.tailscale-systray}/bin/tailscale-systray";
      Environment = [ "DBUS_SESSION_BUS_ADDRESS=unix:path=%t/bus" ];
    };
  };
}