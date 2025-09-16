# auto-login.nix automatically logs in for the first user listed in the users-list.nix file
{ lib, ... }:

let
  userList = import ../config/users-list.nix;
  usersArr  = userList.users or [];
  firstName = if usersArr == [] then null else (builtins.head usersArr).name or null;
in
{
  # Only set autologin if we found a first user
  config = lib.mkIf (firstName != null) {
    services.displayManager.autoLogin.enable = lib.mkDefault true;
    services.displayManager.autoLogin.user   = lib.mkDefault firstName;
  };
}