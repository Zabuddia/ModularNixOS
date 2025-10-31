{ scheme, host, port, lanPort, streamPort, expose, edgePort}:

{ config, pkgs, unstablePkgs, lib, ... }:

let
  companionPort = 8282;
  companionPath = "/companion";
  companionKey  = "kKg3RKeZjE7frmuw";  # MUST match settings.invidious_companion_key
in
{
  ############################
  # Invidious Companion (Podman)
  ############################
  virtualisation.podman.enable = true;
  virtualisation.oci-containers.backend = lib.mkDefault "podman";

  virtualisation.oci-containers.containers.invidious-companion = {
    image = "quay.io/invidious/invidious-companion:latest";
    # Host networking keeps 127.0.0.1:8282 simple/reliable. Do NOT set `ports` with host net.
    extraOptions = [ "--network=host" "--pull=always" ];
    environment = {
      SERVER_SECRET_KEY = companionKey;                           # auth for Invidious
      HOST              = "127.0.0.1";                            # listen only on loopback
      PORT              = toString companionPort;                 # "8282"
      SERVER_BASE_URL   = "http://127.0.0.1:${toString companionPort}";
      # If needed later for YouTube egress:
      # HTTP_PROXY  = "http://proxy.example:3128";
      # HTTPS_PROXY = "http://proxy.example:3128";
      # NO_PROXY    = "127.0.0.1,localhost";
    };
  };

  ############################
  # Invidious (points to Companion)
  ############################
  services.invidious = {
    enable = true;
    package = unstablePkgs.invidious;

    address = "127.0.0.1";
    port = port;
    nginx.enable = false;
    sig-helper.enable = false;

    settings = {
      domain = host;
      https_only = (scheme == "https");
      external_port = port;

      # IMPORTANT: keep the /companion path here
      invidious_companion = [
        { private_url = "http://127.0.0.1:${toString companionPort}${companionPath}"; }
      ];
      invidious_companion_key = companionKey;

      # If you later expose Companion publicly, also set:
      # invidious_companion_public_url = "${scheme}://${host}${companionPath}";
    };
  };

  # Ensure Invidious starts after the companion container is up
  systemd.services.invidious = let dep = "podman-invidious-companion.service"; in {
    wants    = [ dep ];
    after    = [ dep ];
    requires = [ dep ];
  };
}