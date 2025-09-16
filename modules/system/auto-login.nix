# auto-login.nix automatically logs in the first user for the host in users-list.nix
{ lib, ulist, ... }:

let
  usersArr  = ulist.users or [];
  firstName = if usersArr == [] then null else (builtins.head usersArr).name or null;
in
{
  config = lib.mkIf (firstName != null) {
    services.displayManager.autoLogin.enable = lib.mkDefault true;
    services.displayManager.autoLogin.user   = lib.mkDefault firstName;
  };
}
