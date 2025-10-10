{ config, lib, pkgs, hostServices ? [], ... }:

let
  # Extract FQDNs from hostServices (.host preferred, else .domain)
  fqdnOf = s: (s.host or s.domain or null);
  uniqFqdns =
    let all = builtins.filter (x: x != null) (map fqdnOf hostServices);
    in lib.unique all;

  # Simple zone: last two labels (fits zabuddia.org)
  zoneOf = fqdn:
    let ps = lib.splitString "." fqdn; n = builtins.length ps;
    in if n >= 2 then "${builtins.elemAt ps (n - 2)}.${builtins.elemAt ps (n - 1)}" else fqdn;

  zone =
    if uniqFqdns == [] then null else zoneOf (builtins.head uniqFqdns);

  sameZone = lib.all (d: zoneOf d == zone) uniqFqdns;

  # Build one ddclient stanza per hostname
  mkStanza = hostname: ''
    zone=${zone}
    login=token
    password=/run/credentials/ddclient/token
    ${hostname}
  '';

  stanzas = lib.concatStringsSep "\n\n" (map mkStanza uniqFqdns);

  ddclientConf = ''
    # Poll every 300s
    daemon=300
    # Cloudflare API
    protocol=cloudflare
    # Detect public IPv4 via ipify
    use=web, web=ipify-ipv4

    # --- Records (generated from hostServices) ---
    ${stanzas}
  '';

in {
  assertions = [
    {
      assertion = uniqFqdns != [];
      message = "ddclient: No FQDNs found in hostServices (.host or .domain).";
    }
    {
      assertion = sameZone;
      message = "ddclient: Multiple zones detected; this simple config expects a single zone.";
    }
  ];

  # Write ddclient.conf (no secrets inside)
  services.ddclient = {
    enable = true;
    configFile = pkgs.writeText "ddclient.conf" ddclientConf;
  };

  # Provide the token securely via systemd credentials
  # Put your token (just the token text, no quotes) at /etc/ddclient.token (0600)
  systemd.services.ddclient.serviceConfig.LoadCredential = [
    "token:/etc/ddclient.token"
  ];
}