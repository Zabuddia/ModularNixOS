{ lib, pkgs, ... }:

let
  userList = import ../config/users-list.nix;
  userNames = map (u: u.name) (userList.users or []);
in
{
  config = lib.mkMerge [
    {
      programs.wireshark = {
        enable = true;
        package = pkgs.wireshark;  # use pkgs.wireshark-cli if you only need TUI
        dumpcap.enable = true;     # capture as non-root
        usbmon.enable = false;
      };
    }

    # Append "wireshark" to each user from users-list.nix
    (lib.mkIf (userNames != []) (lib.mkMerge (map
      (n: { users.users.${n}.extraGroups = lib.mkAfter [ "wireshark" ]; })
      userNames)))
  ];
}