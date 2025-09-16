# auto-login.nix automatically logs in for the first user listed in the users-list.nix file
{ config, lib, pkgs, ... }:

let
  allUsers = lib.attrNames config.users.users;
  firstUser = lib.head allUsers;
in
{
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = firstUser;
}