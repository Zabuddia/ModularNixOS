{ config, lib, pkgs, hostServices ? [], ... }:

let
  passwordPath = "/etc/cloudflare-ddns-token";

  # FQDNs from your service defs (.host preferred, else .domain)
  fqdnOf = s: (s.host or s.domain or null);
  uniqFqdns =
    let all = builtins.filter (x: x != null) (map fqdnOf hostServices);
    in lib.unique all;

  # Extract zone as last-two labels (simple case)
  zoneOf = fqdn:
    let
      ps = lib.splitString "." fqdn;
      n  = builtins.length ps;
    in
      if n >= 2 then
        "${builtins.elemAt ps (n - 2)}.${builtins.elemAt ps (n - 1)}"
      else
        fqdn;

  # Map: zone -> [ fqdn1 fqdn2 ... ]
  zonesToDomains =
    lib.foldl' (acc: d:
      let z = zoneOf d; prev = acc.${z} or [];
      in acc // { ${z} = prev ++ [ d ]; }
    ) {} uniqFqdns;

  # Build inadyn.providers attrset: "<zone>@cloudflare.com" => { username=<zone>; ... }
  providers =
    lib.genAttrs (lib.attrNames zonesToDomains) (z: {
      # key "z@cloudflare.com" encodes the provider system (cloudflare.com)
      # and gives this block a unique name per zone
      # NixOS module uses the key suffix to set the provider system.
      username = z;                     # <-- Cloudflare requires the zone here
      password = passwordPath;          # API token file
      hostname = zonesToDomains.${z};   # all FQDNs in this zone
      # Optional:
      # proxied = true;                 # keep orange cloud on
      # ttl = 120;
    });
in
{
  assertions = [
    { assertion = uniqFqdns != [];
      message = "inadyn: No FQDNs found in hostServices (.host or .domain)."; }
  ];

  services.inadyn = {
    enable = true;
    settings = {
      period = 300;                     # every 5 min
      # allow-ipv6 = false;             # uncomment to force IPv4-only
      provider = lib.mapAttrs' (z: v: {
        name = "${z}@cloudflare.com";   # set provider system via the key
        value = v;
      }) providers;
    };
  };
}