{ lib, config, pkgs, ... }:

{
  ############################################
  ## Never auto-suspend / hibernate
  ############################################
  services.logind = {
    # Ignore phantom lid events on desktops/servers.
    lidSwitch = "ignore";
    lidSwitchDocked = "ignore";
    lidSwitchExternalPower = "ignore";

    # Ignore power button and idle-triggered suspend.
    powerKey = "ignore";

    extraConfig = ''
      IdleAction=ignore
      IdleActionSec=0
    '';
  };

  ############################################
  ## Optional: disable UPower if not needed
  ############################################
  services.upower.enable = lib.mkDefault false;
  services.upower.criticalPowerAction = lib.mkDefault "Nothing";

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