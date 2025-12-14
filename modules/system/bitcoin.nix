{ lib, pkgs, ulist, ... }:

let
  userNames = map (u: u.name) (ulist.users);
in
{
  config = lib.mkMerge [
    {
      # Run a local Bitcoin Core node (bitcoind)
      services.bitcoind = {
        enable = true;

        # Optional: keep disk usage low (still a validating node)
        # prune = 550;
      };
    }

    # Append "bitcoind" to each user in ulist
    (lib.mkIf (userNames != []) (lib.mkMerge (map
      (n: { users.users.${n}.extraGroups = lib.mkAfter [ "bitcoind" ]; })
      userNames)))
  ];
}
