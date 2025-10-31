{ config, lib, pkgs, hostServices ? [], ... }:

let
  # Pull FQDNs from hostServices (.host preferred, else .domain)
  fqdnOf = s: (s.host or s.domain or null);
  fqdns  = lib.unique (lib.filter (x: x != null) (map fqdnOf hostServices));

  # Derive zone = last two labels of the first fqdn
  zoneOf = fqdn:
    let parts = lib.splitString "." fqdn; n = builtins.length parts;
    in if n >= 2 then
         "${builtins.elemAt parts (n - 2)}.${builtins.elemAt parts (n - 1)}"
       else fqdn;
  zone = if fqdns != [] then zoneOf (builtins.head fqdns) else "example.org";

  # --- Paste your Cloudflare token here ---
  token = "TvCzOXMSM7qJu-QQtp8wy9tGJy0hnDBhcXeiWItx";

  # Build config exactly in your preferred format
  header = ''
    daemon=300 \
    protocol=cloudflare \
    use=web, web=ipify-ipv4 \
  '';

  blockFor = fqdn: ''
    zone=${zone} \
    password='${token}' \
    ${fqdn}
  '';

  confText = ''
    ${header}

    ${lib.concatStringsSep "\n\n" (map blockFor fqdns)}
  '';

  confFile = pkgs.writeText "ddclient.conf" confText;
in {
  services.ddclient = {
    enable = true;
    package = pkgs.ddclient;
    configFile = confFile;
  };
}