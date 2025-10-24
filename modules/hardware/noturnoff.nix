{ lib, config, pkgs, ... }:

{
  ############################################
  ## Never auto-suspend / hibernate
  ############################################
  services.logind = {
    lidSwitch = "ignore";
    lidSwitchDocked = "ignore";
    lidSwitchExternalPower = "ignore";
    powerKey = "ignore";  # optional but safer for headless boxes
    extraConfig = ''
      IdleAction=ignore
      IdleActionSec=0
    '';
  };

  ############################################
  ## Optional: disable UPower if not needed
  ############################################
  services.upower.enable = lib.mkDefault false;
  services.upower.criticalPowerAction = lib.mkDefault "Ignore";

  ############################################
  ## Persistent logs (helpful for diagnosing crashes)
  ############################################
  services.journald.extraConfig = lib.mkDefault ''
    Storage=persistent
  '';

  ############################################
  ## Enable crash dumps (for real crashes, not suspend)
  ############################################
  boot.crashDump.enable = lib.mkDefault true;
}