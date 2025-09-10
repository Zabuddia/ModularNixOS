{ config, pkgs, lib, ... }:

let
  # Build a library path that includes libstdc++ from the toolchain.
  # We'll prepend this to LD_LIBRARY_PATH for Codium so Continue works.
  ldPath = lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ];
in
{
  home.packages = [ pkgs.vscodium ];

  # Desktop entry for VSCodium with the LD_LIBRARY_PATH fix.
  xdg.desktopEntries.codium = {
    name = "VSCodium";
    genericName = "Code Editor";
    comment = "Visual Studio Code without telemetry";

    # IMPORTANT: Escape the $ so the desktop-file validator doesn't complain.
    # Exec is NOT run through a shell, so "$LD_LIBRARY_PATH" must be written as "\$LD_LIBRARY_PATH".
    exec = "env LD_LIBRARY_PATH=${ldPath}:\\$LD_LIBRARY_PATH ${pkgs.vscodium}/bin/codium %F";

    icon = "vscodium";
    terminal = false;
    type = "Application";

    # Only one main category; keep "Development". "TextEditor" is a valid additional category.
    categories = [ "Development" "TextEditor" ];

    mimeType = [ "text/plain" ];

    # Extra unmapped keys go under `settings` (capitalization must match .desktop spec).
    settings = {
      StartupWMClass = "VSCodium";
      StartupNotify = "false";
    };
  };

  # Remove protocol handlers so vscode:// and code:// aren't hijacked by Codium
  xdg.mimeApps = {
    enable = true;
    associations.removed = {
      "x-scheme-handler/vscode" = [ "codium.desktop" "vscode.desktop" ];
      "x-scheme-handler/code"   = [ "codium.desktop" "vscode.desktop" ];
    };
    defaultApplications = {
      "x-scheme-handler/vscode" = [ ];
      "x-scheme-handler/code"   = [ ];
    };
  };

  # Belt-and-suspenders: a dummy URL handler in case something re-adds it.
  home.file.".local/share/applications/codium-url-handler.desktop".text = ''
    [Desktop Entry]
    NoDisplay=true
    Hidden=true
    Name=Ignore This
    Exec=true
    Type=Application
  '';

  # Install extensions after files are written; idempotent & resilient.
  home.activation.installCodiumExtensions = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    set -eu

    CODIUM_BIN="${pkgs.vscodium}/bin/codium"
    PATH="${pkgs.coreutils}/bin:${pkgs.gnugrep}/bin:$PATH"

    # Ensure extensions dir exists (avoids first-run prompts)
    mkdir -p "$HOME/.vscode-oss/extensions"

    install_extension_if_missing() {
      ext="$1"
      if "$CODIUM_BIN" --list-extensions | grep -qx "$ext"; then
        echo "Extension $ext already installed."
      else
        echo "Installing extension: $ext"
        # Don't fail the whole HM switch if network is down, etc.
        "$CODIUM_BIN" --install-extension "$ext" || true
      fi
    }

    install_extension_if_missing continue.continue
    install_extension_if_missing tabbyml.vscode-tabby
    install_extension_if_missing ms-python.python
    install_extension_if_missing rust-lang.rust-analyzer
    install_extension_if_missing bbenoist.nix
    install_extension_if_missing esbenp.prettier-vscode
    install_extension_if_missing zaaack.markdown-editor
  '';
}
