{ lib, pkgs, ulist, ... }:

let
  userNames = map (u: u.name) (ulist.users);
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

    # Append "wireshark" to each user in ulist
    (lib.mkIf (userNames != []) (lib.mkMerge (map
      (n: { users.users.${n}.extraGroups = lib.mkAfter [ "wireshark" ]; })
      userNames)))
  ];
}