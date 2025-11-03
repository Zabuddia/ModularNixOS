{ config, pkgs, lib, ... }:

let
  iface = "wlan0"; # change to your active network interface
in
{
  # ensure local discovery works
#   services.avahi = {
#     enable = true;
#     nssmdns = true;
#   };

  # optional firewall open for Cast traffic (UDP 32768–61000 is used by Openscreen)
  networking.firewall.allowedUDPPorts = [ 32768 61000 ];

  systemd.services.shanocast = {
    description = "Shanocast Chromecast Receiver";
    after = [ "network-online.target" "avahi-daemon.service" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      ExecStart = "${pkgs.nixFlakes}/bin/nix run github:shanocast/shanocast#shanocast -- ${iface}";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };
}
