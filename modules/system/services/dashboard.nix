{ scheme, host, port, lanPort, streamPort, expose, edgePort }:
{ config, pkgs, lib, ... }:

let
  # choose a tailscale "home" for the header chip
  tsRecs  = lib.filter (r: r.expose == "tailscale") recs;
  tsHomeHost =
    if tsRecs != [] && (builtins.head tsRecs).tsHost != null
    then (builtins.head tsRecs).tsHost
    else "set-a-domain-in-svcDefs";

  mkCard = r:
    let
      pathSuffix = if r.name == "guacamole" then "/guacamole" else "/";
      domain     = if r.expose == "tailscale" then (r.tsHost or "missing-domain") else r.hostLabel;
      base = if r.expose == "caddy-wan"
       then "${r.edgeScheme}://${domain}"   # no :port
       else "${r.edgeScheme}://${domain}:${toString r.lanPort}";
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

  cards = lib.concatStrings (map mkCard (lib.filter (r: r.name != "dashboard") recs));

  dashHtml = ''
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
        <div class="sub">Quick links to services on this node.</div>
        <div class="grid">
          ${cards}
        </div>
        <footer>Pro tip: add this page to your home screen for a one-tap hub. ⚡</footer>
      </div>
    </body>
    </html>
  '';
in
{
  # Write static HTML into /etc (immutable, store-backed)
  environment.etc."expose-dash/index.html" = { text = dashHtml; mode = "0644"; };

  # Serve the static page directly from /etc
  systemd.services.expose-dashboard = {
    description = "Expose dashboard (static) - local HTTP";
    wantedBy    = [ "multi-user.target" ];
    after       = [ "network-online.target" ];
    wants       = [ "network-online.target" ];

    serviceConfig = {
      Type = "simple";
      DynamicUser = true;

      # No copy step — serve directly from /etc
      WorkingDirectory = "/etc/expose-dash";
      ExecStart = "${pkgs.python3}/bin/python -m http.server ${toString port} --bind 127.0.0.1";

      ReadOnlyPaths = [ "/etc/expose-dash" ];
      ProtectSystem = "strict";
      ProtectHome   = true;
      PrivateTmp    = true;

      Restart = "on-failure";
      RestartSec = 2;
    };
  };
}