{ config, pkgs, lib, ... }:

# Drop-in VSCodium module for Home-Manager.
# - Installs VSCodium
# - Adds a desktop entry that injects libstdc++ so Continue works
# - Leaves MIME handlers alone (modular; no ~/.config/mimeapps.list ownership)
# - Idempotently installs your preferred extensions
let
  # Build a library path that includes libstdc++ from the toolchain.
  # We don't reference $LD_LIBRARY_PATH to keep it desktop-file friendly.
  ldFix = "LD_LIBRARY_PATH=${lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ]}";
in
{
  home.packages = [ pkgs.vscodium ];

  # Desktop entry (explicit store paths for portability; no profile assumptions).
  home.file.".local/share/applications/codium.desktop".text = ''
    [Desktop Entry]
    Name=VSCodium
    Comment=Visual Studio Code without telemetry
    GenericName=Code Editor
    Exec=env ${ldFix} ${pkgs.vscodium}/bin/codium %F
    Icon=vscodium
    Type=Application
    StartupNotify=false
    StartupWMClass=VSCodium
    Categories=Development;TextEditor;
    MimeType=text/plain;
  '';

  # Optional: dummy URL handler to neuter any accidental scheme registrations.
  home.file.".local/share/applications/codium-url-handler.desktop".text = ''
    [Desktop Entry]
    NoDisplay=true
    Hidden=true
    Name=Ignore This
    Exec=true
    Type=Application
  '';

  # Install extensions after files are written; robust & idempotent.
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
    install_extension_if_missing llvm-vs-code-extensions.vscode-clangd
    install_extension_if_missing jeff-hykin.better-cpp-syntax
    install_extension_if_missing vadimcn.vscode-lldb
  '';
}
