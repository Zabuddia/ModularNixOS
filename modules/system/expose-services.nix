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
    streamPort    = s.streamPort or null;
    backend       = "http://127.0.0.1:${toString port}";
    hostLabel     = (s.host or s.domain or config.networking.hostName);
    backendHost   = (s.host or s.domain or config.networking.hostName);
    backendScheme = "http";
  }) indexed;

  tsRecs  = lib.filter (r: r.expose == "tailscale") recs;
  cdyRecs = lib.filter (r: r.expose == "caddy")     recs;

  # ---------- Dashboard (static HTML TEMPLATE) ----------
  dashPort = basePort - 1;

  # Build table rows; Tailscale URLs now use a placeholder we fill at runtime (''${TS_HOST})
  dashHtml = let
    rows = lib.concatStringsSep "\n" (map (r:
      let
        pathSuffix = if r.name == "guacamole" then "/guacamole" else "/";
        caddyUrl =
          if r.expose == "caddy" then
            "${r.edgeScheme}://${r.hostLabel}:${toString r.lanPort}${pathSuffix}"
          else null;

        # CHANGED: literal ${TS_HOST} placeholder (escaped for Nix with a leading '')
        tsHostLiteral = "$" + "{TS_HOST}";

        tsUrl =
          if r.expose == "tailscale" then
            "${r.edgeScheme}://${tsHostLiteral}:${toString r.lanPort}${pathSuffix}"
          else
            null;

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
        Tailscale dashboard: <strong>https://''${TS_HOST}:${toString basePort}</strong>
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
        Tailscale links are resolved at runtime to this machine’s MagicDNS name or Tailscale IP.
      </p>
    </body>
    </html>
  '';

  # NEW: install the template at a fixed path
  dashTplPath = "expose-dash/index.tpl.html";
  renderedDir = "/var/lib/expose-dash";   # where the rendered file lives
  renderedFile = "${renderedDir}/index.html";

  # install template
  etcDashTpl = {
    "${dashTplPath}" = {
      text = dashHtml;
      mode = "0644";
    };
  };

  # NEW: oneshot renderer that resolves TS_HOST and renders index.html
  renderScript = pkgs.writeShellScript "render-expose-dash" ''
    set -euo pipefail
    TS="${pkgs.tailscale}/bin/tailscale"
    JQ="${pkgs.jq}/bin/jq"
    ENVSUBST="${pkgs.gettext}/bin/envsubst"
    CAT="${pkgs.coreutils}/bin/cat"
    INSTALL="${pkgs.coreutils}/bin/install"
    MKDIR="${pkgs.coreutils}/bin/mkdir"

    # Prefer MagicDNS; fall back to IPv4, then IPv6
    TS_DNS="$($TS status --json | $JQ -r '.Self.DNSName // empty' || true)"
    TS4="$($TS ip -4 2>/dev/null | head -n1 || true)"
    TS6="$($TS ip -6 2>/dev/null | head -n1 || true)"

    TS_HOST="$TS_DNS"
    if [ -z "$TS_HOST" ]; then TS_HOST="$TS4"; fi
    if [ -z "$TS_HOST" ]; then TS_HOST="$TS6"; fi
    if [ -z "$TS_HOST" ]; then TS_HOST="tailscale-not-up"; fi

    $MKDIR -p ${renderedDir}
    $CAT /etc/${dashTplPath} | TS_HOST="$TS_HOST" $ENVSUBST > ${renderedFile}
  '';

  renderService = {
    description = "Render expose dashboard with Tailscale host";
    after = [ "tailscaled.service" "network-online.target" ];
    wants = [ "network-online.target" ];
    requires = [ "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = renderScript;
    };
  };

  # ---------- Tiny local HTTP server for the dashboard (CHANGED to serve renderedDir)
  dashboardService = {
    description = "Expose dashboard (static) - local HTTP";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" "render-expose-dash.service" ];
    wants = [ "network-online.target" "render-expose-dash.service" ];
    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python -m http.server ${toString dashPort} --bind 127.0.0.1";
      WorkingDirectory = renderedDir;  # serve the RENDERED html
      DynamicUser = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
    };
  };

  # ---------- Tailscale serve ----------
  tsLines = lib.concatStringsSep "\n" (
    [ "${pkgs.tailscale}/bin/tailscale serve --bg --https=${toString basePort} --set-path=/ http://127.0.0.1:${toString dashPort}" ]
    ++ (map (r:
      let
        flag = if r.edgeScheme == "https" then "--https" else "--http";
        base = "${pkgs.tailscale}/bin/tailscale serve --bg ${flag}=${toString r.lanPort}";
        mapRoot   = "${base} --set-path=/       ${r.backend}";
        mapStream = lib.optionalString (r.streamPort != null)
                      "${base} --set-path=/stream http://127.0.0.1:${toString r.streamPort}";
      in lib.concatStringsSep "\n" [ mapRoot mapStream ]
    ) tsRecs)
  );

  # ---------- Caddy ----------
  caddyHTTPS = lib.listToAttrs (map (r: {
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
  }) (lib.filter (r: r.edgeScheme == "https") cdyRecs));

  caddyHTTP = lib.listToAttrs (map (r: {
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
  }) (lib.filter (r: r.edgeScheme == "http") cdyRecs));

  caddyDashboard = {
    "${config.networking.hostName}:443".extraConfig = ''
      bind 0.0.0.0
      tls internal
      reverse_proxy 127.0.0.1:${toString dashPort}
    '';
  };

  caddyVHosts = caddyDashboard // caddyHTTP // caddyHTTPS;

  backendModules =
    let files = map (r: { r = r; path = servicesRoot + "/${r.name}.nix"; }) recs;
    in map (f:
      if builtins.pathExists f.path then import f.path {
        scheme = f.r.backendScheme;
        host   = f.r.backendHost;
        port   = f.r.port;
        lanPort = f.r.lanPort;
        streamPort = f.r.streamPort;
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

  # install template
  environment.etc = etcDashTpl;

  # Start backends
  imports = backendModules;

  # Render runtime HTML with real TS host
  systemd.services.render-expose-dash = renderService;

  # Dashboard local server (serves rendered file)
  systemd.services.expose-dashboard = dashboardService;

  # Tailscale serve
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
  networking.firewall.allowedTCPPorts = [ 443 ];
}