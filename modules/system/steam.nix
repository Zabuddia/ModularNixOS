{ config, pkgs, lib, ... }:

let
  pkgs32 = pkgs.pkgsi686Linux;
in
{
  # Steam itself
  programs.steam = {
    enable = true;

    # Extra runtime deps (both 64-bit and 32-bit where needed)
    extraPackages =
      (with pkgs;  [ libkrb5 alsa-lib cups libudev0-shim vulkan-loader ])
      ++ (with pkgs32; [ alsa-lib cups libkrb5 vulkan-loader ]);
  };

  # GPU userspace + 32-bit drivers for Proton/wine games
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages   = with pkgs;   [ mesa ];
    extraPackages32 = with pkgs32; [ mesa ];
  };

  # Udev rules for common game controllers (Steam Deck, DualShock, etc.)
  hardware.steam-hardware.enable = true;

  # Gamemode as a service (works better than just installing the package)
  programs.gamemode.enable = true;

  # Optional quality-of-life tools
  environment.systemPackages = with pkgs; [
    steam-run
    mangohud
    protonup-qt
  ];

  # System fonts (if you want a reliable default)
  fonts.packages = [ pkgs.noto-fonts ];

  # --- Optional NVIDIA notes (uncomment if using NVIDIA) ---
  # services.xserver.videoDrivers = [ "nvidia" ];
  # hardware.nvidia.modesetting.enable = true;

  # --- Optional Gamescope session (Wayland-friendly fullscreen compositor) ---
  # programs.steam.gamescopeSession.enable = true;
}