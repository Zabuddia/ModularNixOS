{ pkgs, ... }:
{
  services.tailscale = {
    enable = true;
    extraUpFlags = [
      "--accept-routes"
    ];
  };

  environment.systemPackages = [ pkgs.tailscale-systray ];
}
