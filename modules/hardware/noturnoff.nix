{ lib, config, pkgs, ... }:

{
  ############################################
  ## Never auto-suspend / hibernate
  ############################################
  services.logind = {
    lidSwitch = "ignore";
    lidSwitchDocked = "ignore";
    lidSwitchExternalPower = "ignore";
    powerKey = "ignore";
    extraConfig = ''
      IdleAction=ignore
      IdleActionSec=0
    '';
  };

  ############################################
  ## Disable UPower on this host (overrides base)
  ############################################
  services.upower.enable = lib.mkForce false;
  # NOTE: do not set criticalPowerAction here; disabling upower avoids the assertion.

  ############################################
  ## Persistent logs (helpful for diagnosing crashes)
  ############################################
  services.journald.extraConfig = lib.mkDefault ''
    Storage=persistent
  '';

  ############################################
  ## Enable crash dumps
  ############################################
  boot.crashDump.enable = lib.mkDefault true;
}