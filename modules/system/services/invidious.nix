{ scheme, host, port, lanPort, streamPort, expose, edgePort }:

{ config, unstablePkgs, pkgs, lib, ... }:

let
  # Local companion settings
  companionPort = 8282;
  companionPath = "/companion";

  # Random 16-20 characters
  # Use a real random secret in production (e.g., via sops-nix or agenix)
  companionKey = "kKg3RKeZjE7frmuw";
in {
  ############################
  # Invidious Companion (OCI)
  ############################
  virtualisation.oci-containers.backend = lib.mkDefault "podman";

  virtualisation.oci-containers.containers.invidious-companion = {
    image = "quay.io/invidious/invidious-companion:latest";
    # Bind only on loopback; Invidious talks to it locally
    ports = [ "127.0.0.1:${toString companionPort}:${toString companionPort}" ];
    environment = {
      SERVER_SECRET_KEY = companionKey;
    };
  };

  #####################################
  # Invidious (use unstable package)
  #####################################
  services.invidious = {
    enable = true;

    # We’re using Companion now (not the old helper)
    sig-helper.enable = false;

    # Use the normal invidious from unstablePkgs as you had
    package = unstablePkgs.invidious;

    address = "127.0.0.1";
    port = port;

    # We’ll proxy elsewhere (Caddy/NGINX in your other modules)
    nginx.enable = false;

    # These become config.yml entries
    settings = {
      domain = host;
      https_only = (scheme == "https");
      external_port = port;

      # Wire Invidious -> Companion over loopback
      invidious_companion = [
        { private_url = "http://127.0.0.1:${toString companionPort}${companionPath}"; }
      ];
      invidious_companion_key = companionKey;

      # If you plan to proxy /companion publicly (for direct video pathing),
      # uncomment this AND add a reverse proxy route below.
      # invidious_companion_public_url = "${scheme}://${host}${companionPath}";
    };
  };

  # Make sure Invidious starts after Companion is up
  # (unit name for oci-containers on podman)
  systemd.services.invidious = let dep = "podman-invidious-companion.service"; in {
    wants = [ dep ];
    after  = [ dep ];
    requires = [ dep ];
  };

  ############################################
  # (Optional) Caddy route for /companion
  # Only needed if you enable public_url above.
  ############################################
  # services.caddy = lib.mkIf (scheme == "https") {
  #   enable = lib.mkDefault true;
  #   virtualHosts."${host}".routes = [
  #     {
  #       match = [ { path = [ "${companionPath}/*" ]; } ];
  #       handle = [
  #         {
  #           handler = "reverse_proxy";
  #           upstreams = [ { dial = "127.0.0.1:${toString companionPort}"; } ];
  #         }
  #       ];
  #     }
  #   ];
  # };
}