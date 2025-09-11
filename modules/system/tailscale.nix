{ ... }:
{
  services.tailscale = {
    enable = true;
    extraUpFlags = [
      "--accept-routes"
    ];
  };

  environment.systemPackages = [ pkgs.trayscale ];
}
