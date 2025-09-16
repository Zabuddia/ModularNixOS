{ pkgs, ... }:
{
  programs.distrobox = {
    enable = true;
    package = pkgs.distrobox;

    # Automatically keep containers in sync with your HM config
    enableSystemdUnit = true;

    # Example container definition
    containers.ubuntu = {
      image = "docker.io/library/ubuntu:22.04";
      additionalPackages = [ "git" "curl" ]; # install extra tools
    };
  };
}