# auto-login.nix automatically logs in the first user for the host in users-list.nix
# Also you need to make sure the gnome login keyring password is empty by going in Seahorse and changing the password to be blank
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