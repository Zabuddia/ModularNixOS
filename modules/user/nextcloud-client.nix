{ config, lib, pkgs, ... }:
{
  # Install the client binaries into your user environment
  home.packages = with pkgs; [
    nextcloud-client
  ];

  services.nextcloud-client = {
    enable = true;
    startInBackground = true;
  };

  # Prevent it from starting too early
  # https://github.com/NixOS/nixpkgs/issues/206630#issuecomment-1436008585
  systemd.user.services.nextcloud-client = {
    Unit = {
      After = lib.mkForce [ "graphical-session.target" ];
    };
  };
}