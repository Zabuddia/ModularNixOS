{ scheme, host, port, lanPort, streamPort, expose, edgePort }:

{ config, pkgs, unstablePkgs, lib, ... }:
# In order to create accounts on this you must first make an account on http://localhost:<port>
# Then you can access it from another computer via the external URL computed below.
# You have to manually connect to http://localhost:8001/v1 on the Open WebUI GUI (if that's your LLM endpoint).
let
  inherit (lib) mkIf;
  extPort =
    if expose == "caddy-wan" then edgePort else lanPort;

  extPortSuffix =
    if extPort == null || extPort == 80 || extPort == 443 then "" else ":${toString extPort}";

  externalURL = "${scheme}://${host}${extPortSuffix}";
in
{
  services.open-webui = {
    enable = true;
    package = unstablePkgs.open-webui;

    # Bind only locally; expose via LAN or Caddy as you prefer
    host = "127.0.0.1";
    port = port;

    dataDir = "/var/lib/open-webui";

    environment = {
      ENABLE_PERSISTENT_CONFIG = "False";
      ANONYMIZED_TELEMETRY = "False";
      DO_NOT_TRACK = "True";
      SCARF_NO_ANALYTICS = "True";
      WEBUI_AUTH = "True";
      ENABLE_SIGNUP = "True";            # allow self-registration for first local account
      DEFAULT_USER_ROLE = "admin";
      WEBUI_URL = externalURL;

      # Uncomment and set your local endpoints if needed:
      # OPENAI_API_BASE_URL = "http://localhost:8000/v1";
      # OPENAI_API_BASE_URL = "http://localhost:8001/v1";
      # OLLAMA_BASE_URL = "http://localhost:11434";
    };
  };
}