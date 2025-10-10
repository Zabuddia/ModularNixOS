{ config, lib, pkgs, hostServices ? [], ... }:

let
  # Root-only file containing your Cloudflare API token
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

  # (Optional) ship the token once for quick-start; prefer sops/agenix in prod.
  # environment.etc."cloudflare-ddns-token".text = "<YOUR_CF_API_TOKEN>";
  # environment.etc."cloudflare-ddns-token".mode = "0600";

  services.inadyn = {
    enable = true;
    settings = {
      period = 300;          # check/update every 5 minutes
      web = "ipify";         # detect public IPv4; keep it simple
      # ipv6 = false;        # uncomment if you want to disable IPv6 explicitly

      provider = [{
        name     = "cloudflare.com";
        username = "token";                  # literal word "token"
        password = passwordPath;             # API token file path
        hostname = uniqFqdns;                # all your FQDNs
      }];
    };
  };
}