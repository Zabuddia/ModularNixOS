{ scheme, host, port, lanPort, streamPort }:

{ config, pkgs, lib, ... }:
# In order to create accounts on this you must first make an account on http://localhost:port then you can access it from another computer
# You have to manually connect to http://localhost:8001/v1 on the openweb-ui gui
{
  services.open-webui = {
    enable = true;
    package = pkgs.open-webui;
    host = "127.0.0.1";
    port = port;

    environment = {
      ENABLE_PERSISTENT_CONFIG = "False";
      ANONYMIZED_TELEMETRY = "False";
      DO_NOT_TRACK = "True";
      SCARF_NO_ANALYTICS = "True";
      WEBUI_AUTH = "True";
      # ENABLE_SIGNUP = "False";             # disable self-registration
      # DEFAULT_USER_ROLE = "pending";
      WEBUI_URL = "${scheme}://${host}:${toString lanPort}";
      # OPENAI_API_BASE_URL = "http://localhost:8000/v1";
      # OPENAI_API_BASE_URL = "http://localhost:8001/v1";
      # OLLAMA_BASE_URL = "http://localhost:11434";
    };
  };
}