{ config, lib, pkgs, ... }:
let
  cfg = config.programs.kodi;
in
{
  assertions = [{
    assertion = cfg.enable;
    message = "boot-into-kodi.nix: Please import kodi.nix first.";
  }];

  systemd.user.services.kodi-autostart = {
    Unit = {
      Description = "Autostart Kodi on graphical login";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${cfg.package}/bin/kodi --fullscreen";
      Restart = "no";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}