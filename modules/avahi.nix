{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [ avahi ];
  
  services.avahi = {
    enable = true;

    # Enable the NSS mDNS plugin so programs can resolve *.local names
    nssmdns4 = true;

    # Publish local hostname/address so others can find this machine
    publish = {
      enable = true;
      addresses = true;
      workstation = true;
    };

    # If you want Avahi’s ports auto-opened in the firewall, uncomment:
    # openFirewall = true;
  };
}