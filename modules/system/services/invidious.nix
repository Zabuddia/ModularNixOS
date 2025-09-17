{ scheme, host, port }:

{ config, pkgs, lib, ... }:

let
  oldPkgs = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/8406224e30c258025cb8b31704bdb977a8f1f009.tar.gz";
    sha256 = "05l5dy8hkw66rsjgl8v3j277qblknbrbhfa9azmawpajkg52ij7v";
  }) {
    system = pkgs.system;
  };
in
{
  services.invidious = {
    enable = true;
    sig-helper.enable = true;
    package = oldPkgs.invidious;

    # Bind locally; expose via your reverse proxy using `host` externally
    address = "0.0.0.0";
    port = port;

    nginx.enable = false;

    # Optional but recommended so links it generates are correct:
    settings = {
      domain = host;
      https_only = (scheme == "https");
      external_port = port;
    };
  };
}