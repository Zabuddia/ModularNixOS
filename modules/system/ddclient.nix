{ config, lib, pkgs, hostServices ? [], ... }:

let
  # Pull FQDNs from hostServices (.host preferred, else .domain)
  fqdnOf = s: (s.host or s.domain or null);
  uniqFqdns = lib.unique (builtins.filter (x: x != null) (map fqdnOf hostServices));

  # Crude zone: last two labels (works for zabuddia.org)
  zoneOf = fqdn:
    let ps = lib.splitString "." fqdn; n = builtins.length ps;
    in if n >= 2 then "${builtins.elemAt ps (n - 2)}.${builtins.elemAt ps (n - 1)}" else fqdn;

  zone = if uniqFqdns == [] then null else zoneOf (builtins.head uniqFqdns);
  sameZone = lib.all (d: zoneOf d == zone) uniqFqdns;

  # >>> EDIT THIS <<< inline Cloudflare API token (Ubuntu style)
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
    { assertion = uniqFqdns != []; message = "ddclient: No FQDNs found in hostServices (.host or .domain)."; }
    { assertion = sameZone;        message = "ddclient: Multiple zones detected; this simple config expects a single zone."; }
  ];

  # Disable the stock ddclient unit to avoid conflicts
  services.ddclient.enable = false;

  # Write /etc/ddclient.conf (strict perms so ddclient won't whine)
  environment.etc."ddclient.conf" = {
    text = ddclientConf;
    mode = "0600";
    user = "root";
    group = "root";
  };

  # Our own Ubuntu-like persistent service
  systemd.services."ddclient-ubuntu" = {
    description = "Dynamic DNS Client (Ubuntu-like persistent ddclient)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    # Ensure curl exists for ipify checks
    path = [ pkgs.curl ];

    serviceConfig = {
      Type = "simple";
      User = "root";
      ExecStart = "${pkgs.ddclient}/bin/ddclient -foreground -daemon=300 -verbose -file /etc/ddclient.conf";
      Restart = "always";
      RestartSec = "10s";
    };
  };
}