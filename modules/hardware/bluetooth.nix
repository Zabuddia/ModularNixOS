{ config, pkgs, ... }:

{
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;

    # Writes /etc/bluetooth/main.conf
    settings = {
      General = {
        ControllerMode = "dual";   # BR/EDR + LE
        DiscoverableTimeout = 0;   # always discoverable
        PairableTimeout = 0;       # always pairable
      };
    };
  };
}