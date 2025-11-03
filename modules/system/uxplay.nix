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

    # Start exactly with your desktop session, not before
    after     = [ "graphical-session.target" ];
    wants     = [ "graphical-session.target" ];
    wantedBy  = [ "graphical-session.target" ];
    partOf    = [ "graphical-session.target" ];

    # <- this is the key: don’t start until the Wayland socket exists
    unitConfig.ConditionPathExists = "%t/wayland-0";

    serviceConfig = {
      # keep your exact command
      ExecStart = "${unstablePkgs.uxplay}/bin/uxplay -p -fs";
      Environment = [
        "XDG_RUNTIME_DIR=%t"
        "DBUS_SESSION_BUS_ADDRESS=unix:path=%t/bus"
      ];
      Restart = "on-failure";
    };
  };
}