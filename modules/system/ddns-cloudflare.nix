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

  services.inadyn = {
    enable = true;
    settings = {
      period = 300;
      web = "ipify";
      # ipv6 = false;  # uncomment to force IPv4-only

      provider = {
        "cloudflare.com" = {
          username = "token";          # literal word "token"
          password = passwordPath;     # file with your API token
          hostname = uniqFqdns;        # all FQDNs you collected
        };
      };
    };
  };
}