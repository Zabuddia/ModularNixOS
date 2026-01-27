{ config, pkgs, lib, ... }:

{
  services.tor = {
    enable = true;
    client = {
      enable = true;
      socksListenAddress = {
        addr = "127.0.0.1";
        port = 9050;
      };
    };
  };

  environment.systemPackages = with pkgs; [ torsocks ];
}