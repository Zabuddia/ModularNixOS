{ config, lib, pkgs, ... }:

let
  normalUsers =
    lib.attrNames (lib.filterAttrs (_: u: (u.isNormalUser or false)) config.users.users);
in
{
  programs.wireshark = {
    enable = true;
    package = pkgs.wireshark;
    dumpcap.enable = true;
    usbmon.enable = false;
  };

  # Append the group to every normal user already declared elsewhere
  users.users = lib.genAttrs normalUsers (_: {
    extraGroups = lib.mkAfter [ "wireshark" ];
  });
}