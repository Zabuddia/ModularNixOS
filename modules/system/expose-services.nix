{ svcDefs }:
{ config, pkgs, lib, ... }:

let
  basePort = 4430;
  servicesRoot = ./services;

  indexed = lib.genList (i: (builtins.elemAt svcDefs i) // { _idx = i; }) (builtins.length svcDefs);

  recs = map (s: rec {
    name          = s.name or ("svc-" + toString s._idx);
    expose        = s.expose or "caddy";            # "caddy" | "tailscale"
    edgeScheme    = s.scheme or "http";             # "http" | "https" (edge)
    port          = s.port;                          # backend port (always http to backend)
    lanPort       = basePort + s._idx + 1;
    backend       = "http://127.0.0.1:${toString port}";
    hostLabel     = (s.host or s.domain or config.networking.hostName);
    backendHost   = (s.host or s.domain or config.networking.hostName);
    backendScheme = "http";
  }) indexed;

  tsRecs  = lib.filter (r: r.expose == "tailscale") recs;
  cdyRecs = lib.filter (r: r.expose == "caddy")     recs;

  # ---------- Dashboard (static HTML) ----------
  dashPort = basePort - 1;

  # Build a tiny HTML list of services with both exposure links
  dashHtml = let
    rows = lib.concatStringsSep "\n" (map (r:
      let
        caddyUrl =
          if r.expose == "caddy" then
            if r.edgeScheme == "https"
              then "https://${r.hostLabel}:${toString r.lanPort}/"
              else "http://${r.hostLabel}:${toString r.lanPort}/"
          else null;

        tsUrl =
          if r.expose == "tailscale" then
            # Link uses port only; user’s tailnet IP/hostname will vary
            "https://${"$"}{TS-IP}:${toString r.lanPort}/"
          else null;

        caddyCell = if caddyUrl != null then "<a href='${caddyUrl}'>${caddyUrl}</a>" else "—";
        tsCell    = if tsUrl    != null then "${tsUrl}" else "—";
      in
        "<tr><td><code>${r.name}</code></td><td>${lib.toUpper r.expose}</td><td>${lib.toUpper r.edgeScheme}</td><td>${caddyCell}</td><td>${tsCell}</td></tr>"
    ) recs);
  in ''
    <!doctype html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>Services on ${config.networking.hostName}</title>
      <style>
        body { font-family: ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, sans-serif; margin: 2rem; }
        h1 { margin-bottom: .5rem; }
        table { border-collapse: collapse; width: 100%; max-width: 900px; }
        th, td { border: 1px solid #ddd; padding: .5rem .75rem; }
        th { background: #f4f4f5; text-align: left; }
        code { background: #f6f7f9; padding: .1rem .3rem; border-radius: 4px; }
        .note { color: #555; margin-top: .75rem; }
      </style>
    </head>
    <body>
      <h1>${config.networking.hostName} — Services</h1>
      <div class="note">
        Caddy dashboard: <strong>https://${config.networking.hostName}:443</strong><br>
        Tailscale dashboard: <strong>https://&lt;your-tailscale-ip&gt;:${toString basePort}</strong>
      </div>
      <table>
        <thead>
          <tr><th>Name</th><th>Expose</th><th>Edge</th><th>Caddy URL</th><th>Tailscale URL</th></tr>
        </thead>
        <tbody>
          ${rows}
        </tbody>
      </table>
      <p class="note">
        For Tailscale links, replace <code>&lt;your-tailscale-ip&gt;</code> with this machine's Tailscale IP (e.g. from <code>tailscale ip</code>).
      </p>
    </body>
    </html>
  '';

  dashDir = pkgs.writeTextDir "index.html" dashHtml;

  # Tiny local HTTP server for the dashboard
  dashboardService = {
    description = "Expose dashboard (static) - local HTTP";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python -m http.server ${toString dashPort} --bind 127.0.0.1";
      WorkingDirectory = dashDir;
      DynamicUser = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
    };
  };

  # ---------- Tailscale serve ----------
  tsLines = lib.concatStringsSep "\n" (
    # dashboard on basePort
    [ "${pkgs.tailscale}/bin/tailscale serve --bg --https=${toString basePort} http://127.0.0.1:${toString dashPort}" ]
    # per-service
    ++ (map (r:
      let flag = if r.edgeScheme == "https" then "--https" else "--http";
      in "${pkgs.tailscale}/bin/tailscale serve --bg ${flag}=${toString r.lanPort} ${r.backend}"
    ) tsRecs)
  );

  # ---------- Caddy ----------
  caddyHTTP = lib.listToAttrs (map (r: {
    name = ":" + toString r.lanPort;
    value.extraConfig = ''
      bind 0.0.0.0
      reverse_proxy 127.0.0.1:${toString r.port}
    '';
  }) (lib.filter (r: r.edgeScheme == "http") cdyRecs));

  caddyHTTPS = lib.listToAttrs (map (r: {
    name = "${r.hostLabel}:${toString r.lanPort}";
    value.extraConfig = ''
      bind 0.0.0.0
      tls internal
      reverse_proxy 127.0.0.1:${toString r.port}
    '';
  }) (lib.filter (r: r.edgeScheme == "https") cdyRecs));

  # Dashboard vhost at hostname:443 via Caddy (TLS internal)
  caddyDashboard = {
    "${config.networking.hostName}:443".extraConfig = ''
      bind 0.0.0.0
      tls internal
      reverse_proxy 127.0.0.1:${toString dashPort}
    '';
  };

  caddyVHosts = caddyDashboard // caddyHTTP // caddyHTTPS;

  # Backend service module imports (unchanged)
  backendModules =
    let
      files = map (r: { r = r; path = servicesRoot + "/${r.name}.nix"; }) recs;
    in map (f:
      if builtins.pathExists f.path then import f.path {
        scheme = f.r.backendScheme;
        host   = f.r.backendHost;
        port   = f.r.port;
      } else { config, lib, ... }: {
        warnings = [ "expose: backend module not found: ${toString f.path} (skipping '${f.r.name}')" ];
      }
    ) files;

in
{
  assertions = [
    { assertion = lib.all (s: s ? name) svcDefs; message = "expose: each service needs a 'name'."; }
    { assertion = lib.all (s: s ? port) svcDefs; message = "expose: each service needs a 'port'."; }
    { assertion = lib.all (s: (s.expose or "caddy") == "caddy" || (s.expose or "caddy") == "tailscale") svcDefs;
      message = "expose: 'expose' must be \"caddy\" or \"tailscale\"."; }
    { assertion = lib.all (s: (s.scheme or "http") == "http" || (s.scheme or "http") == "https") svcDefs;
      message = "expose: 'scheme' must be \"http\" or \"https\"."; }
  ];

  # Start backends
  imports = backendModules;

  # Dashboard local server
  systemd.services.expose-dashboard = dashboardService;

  # Tailscale serve (dashboard + per-service)
  systemd.services.tailscale-serve = {
    description = "Expose services + dashboard via Tailscale Serve";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" "tailscaled.service" "expose-dashboard.service" ];
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

  # Caddy (always on, to serve dashboard + any caddy services)
  services.caddy = {
    enable = true;
    virtualHosts = caddyVHosts;
  };

  # Open Caddy ports: 443 + any per-service LAN ports
  networking.firewall.allowedTCPPorts =
    [ 443 ] ++ (map (r: r.lanPort) cdyRecs);
}