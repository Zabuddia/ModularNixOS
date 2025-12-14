{ scheme, host, port, lanPort, streamPort, expose, edgePort }:

{ config, lib, pkgs, ... }:
let
  extPort = if expose == "caddy-wan" then edgePort else lanPort;

  extPortSuffix =
    if extPort == null || extPort == 80 || extPort == 443
    then ""
    else ":${toString extPort}";

  externalURL = "${scheme}://${host}${extPortSuffix}";

  bitcoindDataDir = "/var/lib/bitcoind-main";
in
{
  systemd.services.btc-rpc-explorer = {
    description = "BTC RPC Explorer";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" "bitcoind-main.service" ];
    wants = [ "network-online.target" "bitcoind-main.service" ];

    serviceConfig = {
      ExecStart = "${pkgs.btc-rpc-explorer}/bin/btc-rpc-explorer";
      Restart = "on-failure";
      RestartSec = 2;

      DynamicUser = true;

      # Allow reading bitcoind cookie via group permissions
      SupplementaryGroups = [ "bitcoind-main" ];

      # Hardening (optional)
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;

      # Ensure the service can traverse/read the datadir path (still enforced by perms)
      ReadOnlyPaths = [ bitcoindDataDir ];

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
}