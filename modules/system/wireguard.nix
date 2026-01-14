{ config, lib, pkgs, ... }:

{
  # Most kernels already include WireGuard; this makes sure the tooling is there.
  networking.wireguard.enable = true;

  # Userspace tools (wg, wg-quick)
  environment.systemPackages = with pkgs; [
    wireguard-tools
  ];
}
