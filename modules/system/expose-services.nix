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
    edgeHost      = (s.host or s.domain or config.networking.hostName);
    port          = s.port;                          # backend port (always http to backend)
    lanPort       = basePort + s._idx + 1;
    streamPort    = s.streamPort or null;

    # Backend is always local http
    backend       = "http://127.0.0.1:${toString port}";
    backendScheme = "http";

    # Label used for Caddy cards/hosts
    hostLabel     = (s.host or s.domain or config.networking.hostName);

    # NEW: explicit tailscale host to print/use in links (no dynamic lookup)
    tsHost        = s.domain or null;
  }) indexed;

  tsRecs  = lib.filter (r: r.expose == "tailscale") recs;
  cdyRecs = lib.filter (r: r.expose == "caddy")     recs;

  # ---------- Dashboard ----------
  dashPort = basePort - 1;

  # Choose a "home" ts host for the top chip; fall back to a hint if none provided
  tsHomeHost =
    if tsRecs != [] && (builtins.head tsRecs).tsHost != null
    then (builtins.head tsRecs).tsHost
    else "set-a-domain-in-svcDefs";

  dashHtml =
    let
      mkCard = r:
        let
          pathSuffix = if r.name == "guacamole" then "/guacamole" else "/";
          domain     = if r.expose == "tailscale"
                        then (r.tsHost or "missing-domain")
                        else r.hostLabel;
          base       = "${r.edgeScheme}://${domain}:${toString r.lanPort}";
          url        = base + pathSuffix;

          title  = lib.escapeXML r.name;
          sub    = lib.escapeXML (lib.toUpper r.expose + " · " + lib.toUpper r.edgeScheme);

          candidates =
            let bw = base + pathSuffix; in
            [
              (bw + "favicon.ico") (bw + "favicon.png")
              (base + "/favicon.ico") (base + "/favicon.png")
              (bw + "assets/favicon.ico") (bw + "assets/favicon-32x32.png")
              (bw + "core/img/favicon.ico") (bw + "static/favicon.ico") (bw + "img/favicon.ico")
            ];
          dataCandidates = lib.concatStringsSep "|" candidates;
        in
        ''
          <a class="card" href="${url}">
            <div class="thumb-wrap">
              <img class="thumb" alt="${title} icon" data-candidates="${dataCandidates}">
              <div class="thumb-fallback" aria-hidden="true">🌐</div>
            </div>
            <div class="card-title">${title}</div>
            <div class="card-sub">${sub}</div>
            <div class="card-url">${url}</div>
          </a>
        '';

      cards = lib.concatStrings (map mkCard recs);
    in
    ''
      <!doctype html>
      <html lang="en">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width,initial-scale=1">
        <title>${lib.escapeXML config.networking.hostName} · Services</title>
        <style>
          :root { --bg:#0b0e14; --fg:#e6edf3; --muted:#9aa4b2; --accent:#f7d046; }
          * { box-sizing: border-box; }
          body { margin:0; font:16px/1.5 system-ui,-apple-system,Segoe UI,Roboto,Ubuntu,Cantarell,Noto Sans,sans-serif; background:var(--bg); color:var(--fg); }
          .wrap { max-width: 1100px; margin: 0 auto; padding: 28px 20px 40px; }
          h1 { font-size: 28px; margin: 0 0 10px; display:flex; gap:10px; align-items:center; flex-wrap:wrap; }
          h1 .dot { width:10px; height:10px; border-radius:50%; background:var(--accent); display:inline-block; }
          .sub { color: var(--muted); margin-bottom: 16px; }
          .links { display:flex; gap:14px; flex-wrap:wrap; margin-bottom: 20px; }
          .linkchip { display:inline-block; padding:6px 10px; border-radius:10px; background:#121a2a; border:1px solid #1f2633; }
          .linkchip a { color:#ffd86b; text-decoration:none; }
          .grid { display:grid; grid-template-columns: repeat(auto-fill, minmax(260px,1fr)); gap:14px; }
          .card {
            display:block; text-decoration:none; color:inherit;
            border:1px solid #1f2633; background:#0f1420; padding:16px; border-radius:16px;
            transition:transform .08s ease, border-color .15s ease, box-shadow .15s ease;
          }
          .card:hover { transform: translateY(-2px); border-color:#2b3447; box-shadow: 0 6px 24px rgba(0,0,0,.35); }
          .thumb-wrap { position:relative; width:32px; height:32px; margin-bottom:8px; }
          .thumb { width:32px; height:32px; object-fit:contain; border-radius:6px; display:none; }
          .thumb-fallback {
            position:absolute; inset:0; display:inline-flex; align-items:center; justify-content:center;
            font-size:18px; background:#121a2a; border:1px solid #1f2633; border-radius:6px; color:#ffd86b;
          }
          .card-title { font-weight:700; margin-bottom:4px; }
          .card-sub { color: var(--muted); font-size:14px; margin-bottom:10px; min-height:1.5em; }
          .card-url { font-family: ui-monospace,SFMono-Regular,Menlo,Consolas,"Liberation Mono",monospace; font-size:12px; color:#c6d0dc; word-break:break-all; opacity:.9; }
          footer { margin-top:26px; color:var(--muted); font-size:13px; }
        </style>
        <script>
          function tryNext(img) {
            const list = (img.dataset.candidates || "").split("|").filter(Boolean);
            const idx = +(img.dataset.idx || 0);
            if (idx >= list.length) return;
            img.onerror = () => { img.dataset.idx = (idx + 1); tryNext(img); };
            img.onload  = () => { img.style.display = "block"; const fb = img.nextElementSibling; if (fb) fb.style.display = "none"; };
            img.src     = list[idx];
          }
          document.addEventListener("DOMContentLoaded", () => {
            document.querySelectorAll("img.thumb").forEach(tryNext);
          });
        </script>
      </head>
      <body>
        <div class="wrap">
          <h1><span class="dot"></span>${lib.escapeXML config.networking.hostName}</h1>
          <div class="sub">Quick links to services on this node. “Tailscale” links use the domain provided in <code>svcDefs[].domain</code>.</div>
          <div class="links">
            <span class="linkchip">Caddy home:
              <a href="https://${config.networking.hostName}:443">https://${config.networking.hostName}:443</a>
            </span>
            <span class="linkchip">Tailscale home:
              <a href="https://${tsHomeHost}:${toString basePort}">https://${tsHomeHost}:${toString basePort}</a>
            </span>
          </div>
          <div class="grid">
            ${cards}
          </div>
          <footer>Pro tip: add this page to your home screen for a one-tap hub. ⚡</footer>
        </div>
      </body>
      </html>
    '';

  renderedDir  = "/var/lib/expose-dash";
  renderedFile = "${renderedDir}/index.html";

  # Serve the dashboard from a static file; no rendering step
  etcDash = {
    "expose-dash/index.html" = {
      text = dashHtml;
      mode = "0644";
    };
  };

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
        scheme    = f.r.edgeScheme;
        host      = f.r.edgeHost;
        port      = f.r.port;
        lanPort   = f.r.lanPort;
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

    # NEW: if a service is exposed via tailscale, require a domain
    { assertion = lib.all (s: (s.expose or "caddy") != "tailscale" || (s ? domain)) svcDefs;
      message   = "expose: tailscale services must set 'domain' (used as the TS host)."; }
  ];

  # Install static dashboard (no renderer)
  environment.etc = etcDash;

  # Start backends
  imports = backendModules;

  # Local HTTP server for the dashboard
  systemd.services.expose-dashboard = {
    description = "Expose dashboard (static) - local HTTP";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python -m http.server ${toString dashPort} --bind 127.0.0.1";
      WorkingDirectory = renderedDir;
      DynamicUser = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
    };
  };

  # Ensure the directory exists and contains the file
  systemd.tmpfiles.rules = [
    "d ${renderedDir} 0755 root root - -"
    "C ${renderedFile} 0644 root root - /etc/expose-dash/index.html"
  ];

  # Tailscale serve (note: hostname is determined by the node; links use provided domains)
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
        # dashboard at basePort
        ${pkgs.tailscale}/bin/tailscale serve --bg --https=${toString basePort} --set-path=/ http://127.0.0.1:${toString dashPort}
        # services
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

  # Caddy (always on, to serve dashboard + any caddy services)
  services.caddy = {
    enable = true;
    virtualHosts = caddyVHosts;
  };

  # Open Caddy ports: 80, 443 + any per-service LAN ports
  networking.firewall.allowedTCPPorts = [ 80 443 ];
}