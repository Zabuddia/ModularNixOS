# modules/system/services/guacamole.nix
# Minimal, modular Guacamole:
# - Backends bind to 127.0.0.1
# - Expose externally via your caddy/tailscale module using { name="guacamole"; port=<match>; scheme=... }
# - Username/password come from the FIRST user in ulist.users (like your auto-login logic)
#   * If that user has guacPasswordSHA256, we use it (hex; encoding=sha256)
#   * Otherwise we use sha256("changeme") and warn at build time

{ scheme, host, port, lanPort }:
{ unstablePkgs, ulist, config, pkgs, lib, ... }:

let
  usersArr   = ulist.users or [];
  firstUser  = if usersArr == [] then null else builtins.head usersArr;
  firstName  = if firstUser == null then "admin" else (firstUser.name or "admin");

  # Prefer a per-user precomputed SHA-256 (hex). Example in users-list.nix:
  # { name = "alice"; guacPasswordSHA256 = "<hex>"; }
  guacSHA    =
    if firstUser != null && firstUser ? guacPasswordSHA256 then
      firstUser.guacPasswordSHA256
    else
      # hex SHA-256 of "changeme"
      builtins.hashString "sha256" "changeme";

  listenAddr = "127.0.0.1";

  userMappingXml = builtins.toFile "user-mapping.xml" ''
    <user-mapping>
      <authorize username="${firstName}" password="${guacSHA}" encoding="sha256">
        <connection name="SSH">
          <protocol>ssh</protocol>
          <param name="hostname">127.0.0.1</param>
          <param name="port">22</param>
        </connection>
        <connection name="Remote Login">
          <protocol>rdp</protocol>
          <param name="hostname">127.0.0.1</param>
          <param name="port">3389</param>
          <param name="ignore-cert">true</param>
        </connection>
        <connection name="Desktop Sharing">
          <protocol>rdp</protocol>
          <param name="hostname">127.0.0.1</param>
          <param name="port">3390</param>
          <param name="ignore-cert">true</param>
        </connection>
      </authorize>
    </user-mapping>
  '';
in
{
  # Nice warning if you haven’t provided a real hash in users-list.nix
  warnings = lib.optional
    (firstUser == null || !(firstUser ? guacPasswordSHA256))
    "guacamole: using default password for user '${firstName}'. Set 'guacPasswordSHA256' in users-list.nix for a real password (hex SHA-256).";

  # guacd (server)
  services.guacamole-server = {
    enable  = true;
    package = unstablePkgs.guacamole-server;  # use unstable
    host    = listenAddr;                     # bind locally
    userMappingXml = userMappingXml;          # simple file auth
  };

  # web client
  services.guacamole-client = {
    enable         = true;
    package        = unstablePkgs.guacamole-client; # use unstable
    enableWebserver = true;
    settings = {
      guacd-hostname = listenAddr;
      guacd-port     = 4822;  # default guacd port
    };
  };

  # Tomcat serves the Guacamole web UI on localhost:<port>
  services.tomcat = {
    enable = true;
    port   = port;            # your expose module proxies to this
    # (If your NixOS release supports it) you can pin Tomcat to localhost:
    # listenAddress = listenAddr;
  };
}