{ scheme, host, port, lanPort, expose, edgePort, ... }:

{ config, lib, pkgs, ... }:
let
  extPort = if expose == "caddy-wan" then edgePort else lanPort;

  extPortSuffix =
    if extPort == null || extPort == 80 || extPort == 443
    then ""
    else ":${toString extPort}";

  externalURL = "${scheme}://${host}${extPortSuffix}";

  bitcoindDataDir = "/var/lib/bitcoind";
in
{
  systemd.services.btc-rpc-explorer = {
    description = "BTC RPC Explorer";
    wantedBy = [ "multi-user.target" ];

    after = [ "network-online.target" "bitcoind.service" ];
    wants = [ "network-online.target" "bitcoind.service" ];

    serviceConfig = {
      ExecStart = "${pkgs.btc-rpc-explorer}/bin/btc-rpc-explorer";
      Restart = "on-failure";
      RestartSec = 2;

      # Run as a normal locked-down system user (simpler than DynamicUser + cookie perms)
      User = "btc-rpc-explorer";
      Group = "btc-rpc-explorer";
      SupplementaryGroups = [ "bitcoin" ];

      Environment = [
        "BTCEXP_HOST=127.0.0.1"
        "BTCEXP_PORT=${toString port}"
        "BTCEXP_BASEURL=/"
        "BTCEXP_PUBLIC_URL=${externalURL}/"

        "BTCEXP_BITCOIND_HOST=127.0.0.1"
        "BTCEXP_BITCOIND_PORT=8332"
        "BTCEXP_BITCOIND_COOKIE=${bitcoindDataDir}/.cookie"
      ];
    };
  };

  # Create the service user/group
  users.users.btc-rpc-explorer = {
    isSystemUser = true;
    group = "btc-rpc-explorer";
  };
  users.groups.btc-rpc-explorer = {};
}