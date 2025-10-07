{ pkgs, ... }:

{
  services.ollama = {
    enable = true;
    # Optional: set the default model (smallest available)
    models = [ "tinyllama" ];
    # Optional: expose it to your LAN (remove if you don’t need it)
    host = "0.0.0.0";
    port = 11434;
  };
}