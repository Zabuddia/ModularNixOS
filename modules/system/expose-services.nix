{ services
, mode ? "tailscale"            # "tailscale" | "caddy-lan" | "caddy-wan"
, tsBasePort ? 4431             # first TS port (per-service increments)
, caddyBind ? "0.0.0.0"         # LAN bind for caddy-lan (or your LAN IP)
, caddyBasePort ? 8081          # first LAN port (per-service increments)
, wanDomain ? null              # e.g., "zabuddia.org" (required for caddy-wan)
, caddyEmail ? null             # optional: Caddy ACME email
}:
{ config, pkgs, lib, ... }:

let
  # index each service
  indexed = lib.genList (i: (builtins.elemAt services i) // { _idx = i; }) (builtins.length services);

  # minimal record
  recs = map (s: rec {
    name    = s.name or ("svc-" + toString s._idx);
    path    = s.path or "";
    backend = "${s.scheme}://127.0.0.1:${toString s.port}${path}";
    tsPort  = (s.externalPort or (tsBasePort  + s._idx));
    lanPort = (s.externalPort or (caddyBasePort + s._idx));
    wanHost = if s ? wanHost then s.wanHost else
              if wanDomain == null then null else "${lib.toLower s.name}.${wanDomain}";
    backendPort = s.port;
  }) indexed;

  # script lines for tailscale serve
  tsLines = lib.concatStringsSep "\n" (map (r:
    "${pkgs.tailscale}/bin/tailscale serve --bg --https=${toString r.tsPort} ${r.backend}"
  ) recs);

  # caddy virtualHosts attrset (LAN)
  caddyLanVHosts = lib.listToAttrs (map (r: {
    name = ":" + toString r.lanPort;
    value.extraConfig = ''
      bind ${caddyBind}
      encode zstd gzip
      reverse_proxy 127.0.0.1:${toString r.backendPort}
    '';
  }) recs);

  # caddy virtualHosts attrset (WAN)
  caddyWanVHosts = lib.listToAttrs (map (r:
    assert r.wanHost != null; {
      name = r.wanHost;
      value.extraConfig = ''
        encode zstd gzip
        reverse_proxy 127.0.0.1:${toString r.backendPort}
      '';
    }
  ) recs);

  caddyPortsLAN = map (r: r.lanPort) recs;

in
{
  #### Tailscale Serve (per-port)
  systemd.services.tailscale-serve = lib.mkIf (mode == "tailscale") {
    description = "Expose services via Tailscale Serve";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" "tailscaled.service" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "tailscale-serve-all" ''
        set -eux
        ${pkgs.tailscale}/bin/tailscale serve reset || true
        ${tsLines}
      '';
      ExecStop = "${pkgs.tailscale}/bin/tailscale serve reset";
    };
  };

  #### Caddy (LAN per-port)
  services.caddy = lib.mkIf (mode == "caddy-lan") {
    enable = true;
    virtualHosts = caddyLanVHosts;
  };
  networking.firewall.allowedTCPPorts = lib.mkIf (mode == "caddy-lan") caddyPortsLAN;

  #### Caddy (WAN per-host with HTTPS)
  services.caddy = lib.mkIf (mode == "caddy-wan") {
    enable = true;
    email = lib.mkIf (caddyEmail != null) caddyEmail; # optional
    virtualHosts = caddyWanVHosts;
  };
  # WAN: open 80/443 for ACME + HTTPS
  networking.firewall.allowedTCPPorts = lib.mkIf (mode == "caddy-wan") [ 80 443 ];

  # Quick sanity assertions
  assertions = [
    {
      assertion = (mode != "caddy-wan") || (wanDomain != null);
      message = "expose-services: caddy-wan mode requires wanDomain (e.g. zabuddia.org).";
    }
  ];
}