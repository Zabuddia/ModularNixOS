{ config, lib, pkgs, hostServices ? [], ... }:

let
  # File that YOU create by hand (0600 root:root) with a single line:
  #   password = <your-cloudflare-api-token>
  # The token must allow Zone:Read + DNS:Edit for the zone.
  passwordInclude = "/etc/inadyn-cloudflare.secret";

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

    # You can use the NixOS timer instead of inadyn's 'period', but this is fine.
    settings = {
      period = 300;                 # check every 5 minutes
      forced-update = 2592000;      # keep default: 30 days

      provider = {
        # Cloudflare plugin (either "cloudflare.com" or "default@cloudflare.com" works)
        cloudflare.com = {
          username = zone;          # zone.name, e.g., "zabuddia.org"
          hostname = uniqFqdns;     # all FQDNs you want updated
          ttl = 1;                  # optional: 1 means 'automatic'
          proxied = false;          # set true if you want orange-cloud
          # Pull the token from a small include file to avoid nix-store secrets:
          include = passwordInclude;  # file must contain: password = <token>
        };
      };
    };
  };
}