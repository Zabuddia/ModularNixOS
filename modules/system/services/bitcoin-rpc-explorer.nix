{ scheme, host, port, lanPort, expose, edgePort }:

{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf;

  extPort =
    if expose == "caddy-wan" then edgePort else lanPort;

  extPortSuffix =
    if extPort == null || extPort == 80 || extPort == 443 then "" else ":${toString extPort}";

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
      # Bind the web UI locally; use your reverse proxy (caddy) for external access
      ExecStart = "${pkgs.btc-rpc-explorer}/bin/btc-rpc-explorer";

      Restart = "on-failure";
      RestartSec = 2;

      # Hardening (optional but nice)
      DynamicUser = true;
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;

      Environment = [
        # Web UI listen settings
        "BTCEXP_HOST=127.0.0.1"
        "BTCEXP_PORT=${toString port}"

        # Optional: helpful for some links/behind-proxy setups
        "BTCEXP_BASEURL=/"
        "BTCEXP_PUBLIC_URL=${externalURL}/"

        # RPC connection to your local bitcoind (cookie auth)
        "BTCEXP_BITCOIND_HOST=127.0.0.1"
        "BTCEXP_BITCOIND_PORT=8332"
        "BTCEXP_BITCOIND_COOKIE=${bitcoindDataDir}/.cookie"
      ];
    };
  };
}