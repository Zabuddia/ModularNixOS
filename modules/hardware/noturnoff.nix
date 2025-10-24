{ lib, config, pkgs, ... }:

let
  cfg = config.roles.server;
in
{
  options.roles.server.enable =
    lib.mkEnableOption "Server/Desktop role: never auto-suspend (ignore lid, idle, power key)";

  config = lib.mkIf cfg.enable {
    ############################################
    ## No unexpected suspend/hibernate
    ############################################
    services.logind = {
      # Your culprit: bogus ACPI lid switch on a desktop/HTPC.
      lidSwitch = "ignore";
      lidSwitchDocked = "ignore";
      lidSwitchExternalPower = "ignore";

      # Don't shut down on power button either (optional but safer for headless boxes).
      powerKey = "ignore";

      # Belt & suspenders: no idle-triggered suspend.
      extraConfig = ''
        IdleAction=ignore
        IdleActionSec=0
      '';
    };

    ############################################
    ## Optional: upower is pointless on servers; keep it quiet
    ############################################
    # If you *do* have a UPS integrated with upower, comment these out.
    services.upower.enable = lib.mkDefault false;
    services.upower.criticalPowerAction = lib.mkDefault "Nothing";

    ############################################
    ## (Optional) Persist logs across reboots for post-mortem
    ############################################
    services.journald.extraConfig = lib.mkDefault ''
      Storage=persistent
    '';

    ############################################
    ## (Optional) Capture crash dumps (for real crashes, not suspend)
    ############################################
    boot.crashDump.enable = lib.mkDefault true;
  };
}
