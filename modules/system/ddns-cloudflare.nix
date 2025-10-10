{ config, lib, pkgs, hostServices ? [], ... }:

let
  passwordPath = "/etc/cloudflare-ddns-token";

  # Pull FQDNs from your service defs (.host preferred, else .domain)
  fqdnOf = s: (s.host or s.domain or null);
  uniqFqdns =
    let all = builtins.filter (x: x != null) (map fqdnOf hostServices);
    in lib.unique all;
in
{
  assertions = [
    { assertion = uniqFqdns != [];
      message = "inadyn: No FQDNs found in hostServices (.host or .domain)." ; }
  ];

  # Optionally seed the token file here (prefer sops/agenix in prod)
  # environment.etc."cloudflare-ddns-token".text = "<YOUR_CF_API_TOKEN>";
  # environment.etc."cloudflare-ddns-token".mode = "0600";

  services.inadyn = {
    enable = true;
    settings = {
      period = 300;             # check every 5 minutes
      # allow-ipv6 = false;     # uncomment to force IPv4-only

      provider = {
        "default@cloudflare.com" = {
          username = "token";            # literal "token" for API Tokens
          password = passwordPath;       # file containing the API token
          hostname = uniqFqdns;          # all FQDNs you collected
          # Optional niceties:
          # proxied = true;              # keep orange-cloud on
          # ttl = 120;                   # set TTL if you want
          # checkip-server = "ifconfig.me";  # override check-IP server if desired
        };
      };
    };
  };
}