{ config, lib, pkgs, ... }:

{
  # Most kernels already include WireGuard; this makes sure the tooling is there.
  networking.wireguard.enable = true;

  # Userspace tools (wg, wg-quick)
  environment.systemPackages = with pkgs; [
    wireguard
    wireguard-tools
  ];

  # If you *specifically* want the kernel module package (older kernels / special cases),
  # keep this. It's usually unnecessary on recent kernels, but harmless.
  boot.extraModulePackages = [
    config.boot.kernelPackages.wireguard
  ];
}
