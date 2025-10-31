{ pkgs, ... }:

{
  # Install the tray app for this user
  home.packages = [ pkgs.tailscale-systray ];

  # Start it automatically when you log in to a GUI session
  systemd.user.services.tailscale-systray = {
    Unit = {
      Description = "Tailscale Systray";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.tailscale-systray}/bin/tailscale-systray";
      Restart = "on-failure";
      # harmless hint for mixed Wayland/X11 setups
      Environment = "GDK_BACKEND=wayland,x11";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}