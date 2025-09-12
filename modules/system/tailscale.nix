{ pkgs, lib, ... }:
{
  services.tailscale = {
    enable = true;
    extraUpFlags = [
      "--accept-routes"
    ];
  };

  environment.systemPackages = with pkgs; [
    tailscale-systray
  ];

  # Autostart tailscale-systray for every graphical login
  systemd.user.services.tailscale-systray = {
    Unit = {
      Description = "Tailscale Tray";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.tailscale-systray}/bin/tailscale-systray";
      Restart = "on-failure";
      # Helps on Wayland/Hyprland too
      Environment = "GDK_BACKEND=wayland,x11";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}