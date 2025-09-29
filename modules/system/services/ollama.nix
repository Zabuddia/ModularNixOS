{ scheme, host, port, lanPort, streamPort }:

{ config, pkgs, lib, ... }:
{
  services.ollama = {
    enable = true;
    acceleration = "rocm";  # This replaces the manual OLLAMA_LLM_LIBRARY
    # Optional: preload models
    loadModels = [ "tinyllama" "mistral" ];

    # Optional: force your GPU architecture if needed
    # You can get this from `rocminfo | grep gfx`
    rocmOverrideGfx = "10.3.0";  # Example for gfx1031 (RX 6600, 6800, etc.)

    # Optional: set manual env vars if required
    environmentVariables = {
      HCC_AMDGPU_TARGET = "gfx1030";  # used to be required, may help
    };

    host = "127.0.0.1";
    listenPort = port;
  };

  # Not sure if I need this
  environment.systemPackages = with pkgs; [
    ollama-rocm
  ];
}