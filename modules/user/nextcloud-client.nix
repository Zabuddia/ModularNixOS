{ config, lib, pkgs, ... }:
{
  services.nextcloud-client = {
    enable = true;
    startInBackground = true;
  };

  # This prevents it form starting too early
  # https://github.com/NixOS/nixpkgs/issues/206630#issuecomment-1436008585
  systemd.user.services.nextcloud-client = {
    Unit = {
      After = pkgs.lib.mkForce "graphical-session.target";
    };
  };
}