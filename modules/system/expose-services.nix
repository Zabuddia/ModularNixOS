{ svcDefs
, tsBasePort ? 4431
, caddyBasePort ? 8081
}:
{ config, pkgs, lib, ... }:

let
  # Where your service definition modules live (each as <name>.nix).
  # Adjust this relative path if your tree differs.
  servicesRoot = ./services;

  indexed = lib.genList (i: (builtins.elemAt svcDefs i) // { _idx = i; }) (builtins.length svcDefs);

  recs = map (s: rec {
    name          = s.name or ("svc-" + toString s._idx);
    expose        = s.expose or "caddy";        # "caddy" | "tailscale"
    edgeScheme    = s.scheme or "http";         # edge scheme (how it’s exposed)
    port          = s.port;                      # backend port (we proxy http://127.0.0.1:port)
    lanPort       = caddyBasePort + s._idx;     # derived; no override inputs
    tsPort        = tsBasePort    + s._idx;
    backend       = "http://127.0.0.1:${toString port}";
    # hostname label for Caddy HTTPS certs; prefer explicit domain, else machine hostname
    hostLabel     = (s.host or s.domain or config.networking.hostName);
    # parameters for the backend module (decoupled from edge scheme)
    backendHost   = (s.host or s.domain or config.networking.hostName);
    backendScheme = "http";                     # keep backends on HTTP by default
  }) indexed;

  tsRecs  = lib.filter (r: r.expose == "tailscale") recs;
  cdyRecs = lib.filter (r: r.expose == "caddy")     recs;

  # Tailscale Serve per service: --http/--https
  tsLines = lib.concatStringsSep "\n" (map (r:
    let flag = if r.edgeScheme == "https" then "--https" else "--http";
    in "${pkgs.tailscale}/bin/tailscale serve --bg ${flag}=${toString r.tsPort} ${r.backend}"
  ) tsRecs);

  # Caddy vhosts: HTTP :port; HTTPS host:port with tls internal
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

  caddyVHosts = caddyHTTP // caddyHTTPS;

  # Import backend service modules here so flake doesn’t need to.
  # Each module is expected at ${servicesRoot}/${name}.nix and takes { scheme, host, port }.
  backendModules =
    let
      files = map (r: {
        r = r;
        # path concatenation: path + string → path
        path = servicesRoot + "/${r.name}.nix";
      }) recs;
    in
      map (f:
        if builtins.pathExists f.path then
          import f.path {
            scheme = f.r.backendScheme;
            host   = f.r.backendHost;
            port   = f.r.port;
          }
        else
          { config, lib, ... }: {
            warnings = [
              "expose: backend module not found: ${toString f.path} (skipping '${f.r.name}')"
            ];
          }
      ) files;
in
{
  #### Validate inputs
  assertions = [
    { assertion = lib.all (s: s ? name) svcDefs; message = "expose: each service needs a 'name'."; }
    { assertion = lib.all (s: s ? port) svcDefs; message = "expose: each service needs a 'port'."; }
    { assertion = lib.all (s: (s.expose or "caddy") == "caddy" || (s.expose or "caddy") == "tailscale") svcDefs;
      message = "expose: 'expose' must be \"caddy\" or \"tailscale\"."; }
    { assertion = lib.all (s: (s.scheme or "http") == "http" || (s.scheme or "http") == "https") svcDefs;
      message = "expose: 'scheme' must be \"http\" or \"https\"."; }
  ];

  #### Pull in the backend service modules
  imports = backendModules;

  #### Tailscale Serve
  systemd.services.tailscale-serve = lib.mkIf (tsRecs != []) {
    description = "Expose selected services via Tailscale Serve";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" "tailscaled.service" ];
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

  #### Caddy
  services.caddy = lib.mkIf (cdyRecs != []) {
    enable = true;
    virtualHosts = caddyVHosts;
  };

  #### Open Caddy ports
  networking.firewall.allowedTCPPorts =
    lib.mkIf (cdyRecs != []) (map (r: r.lanPort) cdyRecs);
}