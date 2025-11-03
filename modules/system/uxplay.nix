{ config, unstablePkgs, ... }:

{
  # Open network ports
  networking.firewall = {
    allowedTCPPorts = [ 7000 7001 7100 ];
    allowedUDPPorts = [ 6000 6001 7011 ];
  };

#   # To enable network-discovery
#   services.avahi = {
#     enable = true;
#     nssmdns4 = true;  # printing
#     openFirewall = true; # ensuring that firewall ports are open as needed
#     publish = {
#       enable = true;
#       addresses = true;
#       workstation = true;
#       userServices = true;
#       domain = true;
#     };
#   };

  environment.systemPackages = with unstablePkgs; [ uxplay ];

  # Optional: a simple user service so it always runs with the right flags
  systemd.user.services.uxplay = {
    description = "UxPlay AirPlay receiver";
    after       = [ "graphical-session.target" "avahi-daemon.service" ];
    wantedBy    = [ "graphical-session.target" "default.target" ];
    serviceConfig = {
      ExecStart = "${unstablePkgs.uxplay}/bin/uxplay -p -fs";
      Restart   = "on-failure";
    };
  };
}