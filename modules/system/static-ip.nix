{ lib, host, ... }:

let
  cfg = host.staticIp or null;
in
{
  config = lib.mkIf (cfg != null) {
    networking.networkmanager.enable = true;

    networking.networkmanager.connectionConfig =
      lib.mkIf (cfg.ignoreIpv6 or false) {
        "ipv6.method" = "ignore";
      };

    networking.interfaces.${cfg.iface} = {
      useDHCP = false;
      ipv4.addresses = [{
        address = cfg.address;
        prefixLength = cfg.prefix or 24;
      }];
    };

    networking.defaultGateway = cfg.gateway;
  };
}