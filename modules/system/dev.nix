{ pkgs, lib, ... }:
{
  environment.systemPackages = with pkgs; [
    gcc gnumake cmake ninja pkg-config
    gdb valgrind strace ltrace clang-tools
    gtest

    (python3.withPackages (ps: with ps; [
      pillow
      click
      cryptography
      cbor
      intelhex
    ]))
    
    gcc-arm-embedded
    openocd
    rustup
    jdk
    gradle
    nodejs_20 pnpm yarn
    android-tools
    uv

    imagemagick patchelf

    SDL2 (lib.getDev SDL2)
    SDL2_ttf (lib.getDev SDL2_ttf)
    freetype (lib.getDev freetype)
    zlib (lib.getDev zlib)
    libpng (lib.getDev libpng)
  ];

  environment.variables.JAVA_HOME = pkgs.jdk.home;

  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;
}
