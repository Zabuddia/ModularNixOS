{ scheme, host, port, lanPort, streamPort }:

{ config, unstablePkgs, pkgs, lib, ... }:

# If you ever need to pin back to an older nixpkgs:
# let
#   oldPkgs = import (builtins.fetchTarball {
#     url = "https://github.com/NixOS/nixpkgs/archive/8406224e30c258025cb8b31704bdb977a8f1f009.tar.gz";
#     sha256 = "05l5dy8hkw66rsjgl8v3j277qblknbrbhfa9azmawpajkg52ij7v";
#   }) {
#     system = pkgs.system;
#   };
# in

{
  services.invidious = {
    enable = true;
    sig-helper.enable = true;

    # Use the normal invidious from current pkgs
    package = unstablePkgs.invidious;
    # If you want to go back to the old one, swap to:
    # package = oldPkgs.invidious;

    address = "127.0.0.1";
    port = port;

    nginx.enable = false;

    settings = {
      domain = host;
      https_only = (scheme == "https");
      external_port = port;
    };
  };
}