{ config, pkgs, lib, ... }:

{
  services.tor = {
    enable = true;
    # client.enable = true;  # prevents SocksPort 0 from being injected

    # settings = {
    #   # IMPORTANT: force a single SocksPort, no flags, no duplicates
    #   SocksPort = lib.mkForce [ "127.0.0.1:9052" ];
    #   # Keep it minimal until we're green; add ControlPort later if you want
    # };
  };

  environment.systemPackages = with pkgs; [ torsocks ];
}