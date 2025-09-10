{ config, pkgs, lib, ... }:

let
  # Inject missing libstdc++ and keep any existing LD_LIBRARY_PATH
  ldFix = "LD_LIBRARY_PATH=${lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ]}:\${LD_LIBRARY_PATH}";
in
{
  home.packages = [ pkgs.vscodium ];

  # Clean, portable desktop entry
  xdg.desktopEntries.codium = {
    name = "VSCodium";
    genericName = "Code Editor";
    comment = "Visual Studio Code without telemetry";
    # Use the store path so we don't depend on profile ordering
    exec = "env ${ldFix} ${pkgs.vscodium}/bin/codium %F";
    icon = "vscodium";
    terminal = false;
    type = "Application";
    startupWMClass = "VSCodium";
    categories = [ "Utility" "TextEditor" "Development" "IDE" ];
    mimeType = [ "text/plain" ];
  };

  # Properly remove protocol handlers (prevents vscode:// from hijacking)
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

  # Optional: also drop a hidden handler desktop file in case something re-adds it
  home.file.".local/share/applications/codium-url-handler.desktop".text = ''
    [Desktop Entry]
    NoDisplay=true
    Hidden=true
    Name=Ignore This
    Exec=true
    Type=Application
  '';

  # Install extensions after files are written; be robust and idempotent
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
