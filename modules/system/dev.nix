{ pkgs, lib, ... }:
{
  environment.systemPackages = with pkgs; [
    gcc gnumake cmake ninja pkg-config
    gdb valgrind strace ltrace clang-tools
    gtest

    python3
    python3Packages.pipx
    python3Packages.click
    python3Packages.cryptography
    python3Packages.cbor
    python3Packages.intelhex
    gcc-arm-embedded
    openocd
    rustup
    jdk
    gradle
    nodejs_20 pnpm yarn
    android-tools
    uv

    imagemagick patchelf
  ];

  environment.variables.JAVA_HOME = pkgs.jdk.home;

  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;
}
