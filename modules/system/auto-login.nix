{ user }:
{ config, pkgs, ... }: {
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = user;
}
