{ config, pkgs, ... }:

{
  programs.wireshark = {
    enable = true;
    package = pkgs.wireshark; # or pkgs.wireshark-cli if you only want the CLI
    dumpcap.enable = true;    # allow capture as non-root
    usbmon.enable = false;    # set true if you also want USB captures
  };
}