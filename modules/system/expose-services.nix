# expose-minimal-locked.nix
{ svcDefs
, tsBasePort ? 4431
, caddyBasePort ? 8081
}:
{ config, pkgs, lib, ... }:

let
  # normalize: force http backend, derive ports strictly from bases + index
  indexed = lib.genList (i: (builtins.elemAt svcDefs i) // { _idx = i; }) (builtins.length svcDefs);
  recs = map (s: rec {
    name        = s.name or ("svc-" + toString s._idx);
    port        = s.port;                     # required
    expose      = s.expose or "caddy";        # "caddy" or "tailscale"
    lanPort     = caddyBasePort + s._idx;     # no override allowed
    tsPort      = tsBasePort    + s._idx;     # no override allowed
    backend     = "http://127.0.0.1:${toString port}";
  }) indexed;

  tsRecs  = lib.filter (r: r.expose == "tailscale") recs;
  cdyRecs = lib.filter (r: r.expose == "caddy")     recs;

  tsLines = lib.concatStringsSep "\n" (map (r:
    "${pkgs.tailscale}/bin/tailscale serve --bg --https=${toString r.tsPort} ${r.backend}"
  ) tsRecs);

  caddyVHosts = lib.listToAttrs (map (r: {
    name = ":" + toString r.lanPort;
    value.extraConfig = ''
      bind 0.0.0.0
      tls internal
      reverse_proxy 127.0.0.1:${toString r.port}
    '';
  }) cdyRecs);

in
{
  #### Validate inputs
  assertions = [
    # must have name, port, and valid expose
    { assertion = lib.all (s: s ? name)  svcDefs; message = "expose: each service needs a 'name'."; }
    { assertion = lib.all (s: s ? port)  svcDefs; message = "expose: each service needs a 'port'."; }
    { assertion = lib.all (s: (s.expose or "caddy") == "caddy" || (s.expose or "caddy") == "tailscale") svcDefs;
      message = "expose: 'expose' must be \"caddy\" or \"tailscale\" if set."; }
  ];

  #### Tailscale Serve (only if any)
  systemd.services.tailscale-serve = lib.mkIf (tsRecs != []) {
    description = "Expose selected services via Tailscale Serve";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" "tailscaled.service" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "ts-serve" ''
        set -eux
        ${pkgs.tailscale}/bin/tailscale serve reset || true
        ${tsLines}
      '';
      ExecStop = "${pkgs.tailscale}/bin/tailscale serve reset";
    };
  };

  #### Caddy (LAN per-port), always bind 0.0.0.0
  services.caddy = lib.mkIf (cdyRecs != []) {
    enable = true;
    virtualHosts = caddyVHosts;
  };

  #### Open the derived Caddy ports
  networking.firewall.allowedTCPPorts =
    lib.mkIf (cdyRecs != []) (map (r: r.lanPort) cdyRecs);
}