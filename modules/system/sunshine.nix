# Access with http://localhost:47990
{ config, pkgs, ... }:
{
  services.sunshine = {
    enable = true;
    autoStart = true;
    # openFirewall = true;
    capSysAdmin = true;
  };
}