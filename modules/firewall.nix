{ config, pkgs, ... }:

{
  networking.firewall.enable = true;

  # Open Dolphin Netplay port (default 2626) for both TCP and UDP
  networking.firewall.allowedTCPPorts = [ 2626 ];
  networking.firewall.allowedUDPPorts = [ 2626 ];
}