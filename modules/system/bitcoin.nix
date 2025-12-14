{ lib, pkgs, ulist, ... }:

let
  userNames = map (u: u.name) (ulist.users);
in
{
  config = lib.mkMerge [
    {
      services.bitcoind.main = {
        enable = true;
        dataDir = "/var/lib/bitcoind-main";
        # Optional
        # prune = 550;
        extraConfig = ''
          startupnotify=chmod g+r /var/lib/bitcoind-main/.cookie
        '';
      };
    }

    # Append "bitcoind" group to each user
    (lib.mkIf (userNames != []) (lib.mkMerge (map
      (n: { users.users.${n}.extraGroups = lib.mkAfter [ "bitcoind-main" ]; })
      userNames)))
  ];
}