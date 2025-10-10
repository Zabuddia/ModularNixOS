{ config, lib, pkgs, hostServices ? [], ... }:

let
  passwordPath = "/etc/cloudflare-ddns-token";

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

  # (Optional) seed the token (prefer sops/agenix in prod)
  # environment.etc."cloudflare-ddns-token".text = "<YOUR_CF_API_TOKEN>";
  # environment.etc."cloudflare-ddns-token".mode = "0600";

  services.inadyn = {
    enable = true;
    settings = {
      period = 300;
      web = "ipify";
      # ipv6 = false;  # uncomment if you want to force IPv4-only

      provider = {
        cloudflare = {
          system     = "cloudflare.com";
          username = "token";
          password = passwordPath;
          hostname = uniqFqdns;
        };
      };
    };
  };
}