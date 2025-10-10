{ config, lib, pkgs, hostServices ? [], ... }:

let
  passwordPath = "/etc/cloudflare-ddns-token";

  # FQDNs from your service defs (.host preferred, else .domain)
  fqdnOf = s: (s.host or s.domain or null);
  uniqFqdns =
    let all = builtins.filter (x: x != null) (map fqdnOf hostServices);
    in lib.unique all;

  # Simple zone = last two labels (ok for zabuddia.org)
  zoneOf = fqdn:
    let ps = lib.splitString "." fqdn; n = builtins.length ps;
    in if n >= 2 then "${builtins.elemAt ps (n - 2)}.${builtins.elemAt ps (n - 1)}" else fqdn;

  zone =
    if uniqFqdns == [] then null else zoneOf (builtins.head uniqFqdns);

  # Assert all FQDNs share the same zone (simple, but matches your case)
  sameZone = lib.all (d: zoneOf d == zone) uniqFqdns;

in {
  assertions = [
    { assertion = uniqFqdns != [];
      message = "inadyn: No FQDNs found in hostServices (.host or .domain)."; }
    { assertion = sameZone;
      message = "inadyn: Multiple zones detected; this simple config expects a single zone."; }
  ];

  services.inadyn = {
    enable = true;
    settings = {
      period = 300; # every 5 minutes

      provider = {
        # IMPORTANT: provider id must be exactly this so inadyn finds the plugin
        "default@cloudflare.com" = {
          username = zone;             # e.g., "zabuddia.org"
          password = passwordPath;     # API token file (Zone:Read + DNS:Edit)
          hostname = uniqFqdns;        # all your FQDNs
          # Optional:
          # allow-ipv6 = false;        # force IPv4-only if you want
          # proxied = true;            # keep orange-cloud on
          # ttl = 120;
        };
      };
    };
  };
}