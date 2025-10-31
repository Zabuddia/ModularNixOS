{ pkgs, ... }:

{
  home.packages = with pkgs; [
    retroarch
    libretro-core-info
    retroarch-assets

    # Cores to include
    libretro.dolphin
  ];

  # Symlink the Dolphin core where RetroArch expects it
  home.file.".config/retroarch/cores/dolphin_libretro.so".source =
    "${pkgs.libretro.dolphin}/lib/libretro/dolphin_libretro.so";
}