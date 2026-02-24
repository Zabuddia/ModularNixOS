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
      pyside6
      shiboken6
      pandas
      lxml
      mkdocs
      mkdocs-material
    ]))

    qt6.qtbase
    (qt6.qtbase.dev)
    qt6.qttools
    (qt6.qttools.dev)

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

    # OpenGL / GLX headers + libs for Qt6Gui / Qt6Widgets
    mesa (lib.getDev mesa)
    libGL (lib.getDev libGL)
    libGLU (lib.getDev libGLU)

    # Often needed by Qt on X11
    xorg.libX11
    xorg.libXext
    xorg.libXrandr
    xorg.libXcursor
    xorg.libXi
    xorg.libXrender
    xorg.libxcb

    # --- System fix for the GTK schema crash in Qt native dialogs ---
    glib
    gtk3
    gsettings-desktop-schemas
    adwaita-icon-theme
    # (optional but nice)
    shared-mime-info
  ];

  environment.variables.JAVA_HOME = pkgs.jdk.home;

  # Helps Qt find platform plugins on NixOS when running from ./build/...
  environment.sessionVariables = {
    QT_PLUGIN_PATH = "${pkgs.qt6.qtbase}/${pkgs.qt6.qtbase.qtPluginPrefix}";
  };

  # Make GSettings schemas discoverable (fixes:
  # "Settings schema 'org.gtk.Settings.*' is not installed")
  #
  # IMPORTANT: include existing XDG_DATA_DIRS if it exists, so we don't break other stuff.
  environment.sessionVariables.XDG_DATA_DIRS =
    lib.mkForce (lib.concatStringsSep ":" ([
      "${pkgs.gsettings-desktop-schemas}/share"
      "${pkgs.gtk3}/share"
      "${pkgs.glib}/share"
      "/run/current-system/sw/share"
    ] ++ lib.optional (builtins.getEnv "XDG_DATA_DIRS" != "") (builtins.getEnv "XDG_DATA_DIRS")));

  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;
}