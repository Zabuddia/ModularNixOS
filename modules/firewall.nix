{ config, pkgs, ... }:

{
  networking.firewall = {
    enable = true;

    # Explicitly close SSH (port 22)
    allowedTCPPorts = [];
    allowedUDPPorts = [];

    # Optional but clear — makes sure the SSH service doesn’t open it
    rejectPackets = true;
  };
}