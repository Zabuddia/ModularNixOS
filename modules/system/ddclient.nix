{ config, lib, pkgs, hostServices ? [], extraFqdns ? [], ... }:

let
  # Pull FQDNs from hostServices (.host preferred, else .domain),
  # plus any extra DNS-only names you want managed.
  fqdnOf = s: (s.host or s.domain or null);
  hsFqdns = builtins.filter (x: x != null) (map fqdnOf hostServices);
  allFqdns = lib.unique (hsFqdns ++ extraFqdns);

  # Crude zone: last two labels (works for zabuddia.org)
  zoneOf = fqdn:
    let ps = lib.splitString "." fqdn; n = builtins.length ps;
    in if n >= 2 then "${builtins.elemAt ps (n - 2)}.${builtins.elemAt ps (n - 1)}" else fqdn;

  zone = if allFqdns == [] then null else zoneOf (builtins.head allFqdns);
  sameZone = lib.all (d: zoneOf d == zone) allFqdns;

  # One simple stanza per hostname; login/password come from the secrets include.
  mkStanza = hostname: ''
    zone=${zone}
    ${hostname}
  '';

  stanzas = lib.concatStringsSep "\n\n" (map mkStanza allFqdns);

  # Generated ddclient.conf (NO SECRETS).
  # We include /etc/ddclient.secrets which YOU create locally (root:root, 0600),
  # containing the token (see instructions below).
  ddclientConf = ''
    # Poll every 300s
    daemon=300
    # Cloudflare API
    protocol=cloudflare
    # Detect public IPv4 via ipify
    use=web, web=ipify-ipv4
    # Writable cache (avoid Nix store warnings)
    cache=/var/cache/ddclient/ddclient.cache
    # Pull login/token from a local, root-only file (kept out of Git/Nix store)
    include /etc/ddclient.secrets

    # --- Records (generated) ---
    ${stanzas}
  '';
in {
  assertions = [
    { assertion = allFqdns != []; message = "ddclient: No FQDNs found (hostServices/.host|.domain) and no extraFqdns provided."; }
    { assertion = sameZone;       message = "ddclient: Multiple zones detected; this simple config expects a single zone."; }
  ];

  # Disable the stock ddclient unit to avoid conflicts
  services.ddclient.enable = false;

  # Write /etc/ddclient.conf (strict perms so ddclient won't complain)
  environment.etc."ddclient.conf" = {
    text = ddclientConf;
    mode = "0600";
    user = "root";
    group = "root";
  };

  # Our Ubuntu-like persistent service with readable logs
  systemd.services."ddclient-ubuntu" = {
    description = "Dynamic DNS Client (Ubuntu-like persistent ddclient)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    # ensure curl exists for ipify checks
    path = [ pkgs.curl ];

    serviceConfig = {
      Type = "simple";
      User = "root";
      # Keep running in foreground and loop every 300s
      ExecStart = "${pkgs.ddclient}/bin/ddclient -foreground -daemon=300 -verbose -file /etc/ddclient.conf";
      Restart = "always";
      RestartSec = "10s";

      # Create /var/cache/ddclient automatically (ends up at /var/cache/ddclient)
      CacheDirectory = "ddclient";

      # Don’t start until the secrets file exists (prevents noisy failures)
      ConditionPathExists = "/etc/ddclient.secrets";
    };
  };
}