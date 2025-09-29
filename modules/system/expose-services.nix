{ svcDefs }:
{ config, pkgs, lib, ... }:

let
  basePort     = 4430;
  servicesRoot = ./services;

  indexed = lib.genList (i: (builtins.elemAt svcDefs i) // { _idx = i; }) (builtins.length svcDefs);

  recs = map (s: rec {
    name       = s.name or ("svc-" + toString s._idx);
    expose     = s.expose;                          # must be "caddy-lan", "caddy-wan", or "tailscale"
    edgeScheme = s.scheme or "http";                # "http" | "https"
    edgeHost   = (s.host or s.domain or config.networking.hostName);

    port       = s.port;                            # backend port (always http to backend)
    lanPort    = basePort + s._idx;
    streamPort = s.streamPort or null;

    backend       = "http://127.0.0.1:${toString port}";
    backendScheme = "http";

    hostLabel = (s.host or s.domain or config.networking.hostName);
    tsHost    = s.domain or null;
  }) indexed;

  tsRecs      = lib.filter (r: r.expose == "tailscale") recs;
  cdyLanRecs  = lib.filter (r: r.expose == "caddy-lan") recs;
  cdyWanRecs  = lib.filter (r: r.expose == "caddy-wan") recs;

  # ---------- Caddy LAN ----------
  caddyLanHTTPS = lib.listToAttrs (map (r: {
    name = "${r.hostLabel}:${toString r.lanPort}";
    value.extraConfig = ''
      bind 0.0.0.0
      tls internal
      reverse_proxy 127.0.0.1:${toString r.port}
      ${lib.optionalString (r.streamPort != null) ''
      handle_path /stream* {
        reverse_proxy 127.0.0.1:${toString r.streamPort}
      }
      ''}
    '';
  }) (lib.filter (r: r.edgeScheme == "https") cdyLanRecs));

  caddyLanHTTP = lib.listToAttrs (map (r: {
    name = ":" + toString r.lanPort;
    value.extraConfig = ''
      bind 0.0.0.0
      reverse_proxy 127.0.0.1:${toString r.port}
      ${lib.optionalString (r.streamPort != null) ''
      handle_path /stream* {
        reverse_proxy 127.0.0.1:${toString r.streamPort}
      }
      ''}
    '';
  }) (lib.filter (r: r.edgeScheme == "http") cdyLanRecs));

  # ---------- Caddy WAN ----------
  caddyWanHTTPS = lib.listToAttrs (map (r: {
    name = r.hostLabel;
    value.extraConfig = ''
      bind 0.0.0.0
      reverse_proxy 127.0.0.1:${toString r.port}
      ${lib.optionalString (r.streamPort != null) ''
      handle_path /stream* {
        reverse_proxy 127.0.0.1:${toString r.streamPort}
      }
      ''}
    '';
  }) (lib.filter (r: r.edgeScheme == "https") cdyWanRecs));

  caddyWanHTTP = lib.listToAttrs (map (r: {
    name = r.hostLabel + ":80";
    value.extraConfig = ''
      bind 0.0.0.0
      reverse_proxy 127.0.0.1:${toString r.port}
      ${lib.optionalString (r.streamPort != null) ''
      handle_path /stream* {
        reverse_proxy 127.0.0.1:${toString r.streamPort}
      }
      ''}
    '';
  }) (lib.filter (r: r.edgeScheme == "http") cdyWanRecs));

  caddyVHosts = caddyLanHTTP // caddyLanHTTPS // caddyWanHTTP // caddyWanHTTPS;

  # ---------- Per-service backend modules ----------
  backendModules =
    let files = map (r: { r = r; path = servicesRoot + "/${r.name}.nix"; }) recs;
    in map (f:
      if builtins.pathExists f.path then
        import f.path (
          if f.r.name == "dashboard" then {
            scheme     = f.r.edgeScheme;
            host       = f.r.edgeHost;
            port       = f.r.port;
            lanPort    = f.r.lanPort;
            streamPort = f.r.streamPort;
            recs       = recs;
          } else {
            scheme     = f.r.edgeScheme;
            host       = f.r.edgeHost;
            port       = f.r.port;
            lanPort    = f.r.lanPort;
            streamPort = f.r.streamPort;
          }
        )
      else { config, lib, ... }: {
        warnings = [ "expose: backend module not found: ${toString f.path} (skipping '${f.r.name}')" ];
      }
    ) files;

in
{
  assertions = [
    { assertion = lib.all (s: s ? name) svcDefs;
      message = "expose: each service needs a 'name'."; }

    { assertion = lib.all (s: s ? port) svcDefs;
      message = "expose: each service needs a 'port'."; }

    { assertion = lib.all (s:
        let e = (s.expose or null);
        in e == "caddy-lan" || e == "caddy-wan" || e == "tailscale"
      ) svcDefs;
      message = "expose: 'expose' must be one of \"caddy-lan\", \"caddy-wan\", or \"tailscale\".";
    }

    { assertion = lib.all (s: (s.scheme or "http") == "http" || (s.scheme or "http") == "https") svcDefs;
      message = "expose: 'scheme' must be \"http\" or \"https\"."; }

    { assertion = lib.all (s: (s.expose or null) != "tailscale" || (s ? domain)) svcDefs;
      message   = "expose: tailscale services must set 'domain'."; }

    { assertion = lib.all (s: (s.expose or null) != "caddy-wan" || (s ? host)) svcDefs;
      message   = "expose: caddy-wan services must set 'host' (FQDN)."; }
  ];

  imports = backendModules;

  systemd.services.tailscale-serve = {
    description = "Expose services via Tailscale Serve";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" "tailscaled.service" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "ts-serve" ''
        set -eux
        ${pkgs.tailscale}/bin/tailscale serve reset || true
        ${lib.concatStringsSep "\n" (map (r:
          let
            flag = if r.edgeScheme == "https" then "--https" else "--http";
            base = "${pkgs.tailscale}/bin/tailscale serve --bg ${flag}=${toString r.lanPort}";
            mapRoot   = "${base} --set-path=/       ${r.backend}";
            mapStream = lib.optionalString (r.streamPort != null)
                          "${base} --set-path=/stream http://127.0.0.1:${toString r.streamPort}";
          in lib.concatStringsSep "\n" [ mapRoot mapStream ]
        ) tsRecs)}
      '';
      ExecStop = "${pkgs.tailscale}/bin/tailscale serve reset";
    };
  };

  services.caddy = {
    enable = true;
    virtualHosts = caddyVHosts;
  };

  networking.firewall.allowedTCPPorts =
    [ 443 ] ++ lib.optionals (cdyWanRecs != []) [ 80 ];
}