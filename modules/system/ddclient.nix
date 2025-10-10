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

  # === EDIT THIS: inline Cloudflare API token (like Ubuntu) ===
  token = "REPLACE_ME_WITH_NEW_TOKEN";

  mkStanza = hostname: ''
    zone=${zone}
    login=token
    password='${token}'
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

  # Write an actual /etc/ddclient.conf with strict perms (ddclient hates world-readable)
  environment.etc."ddclient.conf" = {
    text = ddclientConf;
    mode = "0600";
    user = "root";
    group = "root";
  };

  # Enable ddclient and point it at /etc (Ubuntu-style)
  services.ddclient = {
    enable = true;
    configFile = "/etc/ddclient.conf";
  };

  # Make it a persistent daemon with verbose logs (Ubuntu-like status output)
  systemd.services.ddclient.serviceConfig = {
    Type = "simple";
    ExecStart = lib.mkForce ''
      ${pkgs.ddclient}/bin/ddclient \
        -daemon=300 \
        -verbose \
        -file /etc/ddclient.conf
    '';
    Restart = "always";
    RestartSec = "10s";
  };
}