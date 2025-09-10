{ ... }:
{
  services.tailscale.enable = true;

  environment.systemPackages = [ pkgs.trayscale ];
}
