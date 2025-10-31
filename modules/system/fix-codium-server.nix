{ config, pkgs, lib, ... }:

let
  inherit (pkgs) nodejs;

  nodeFixScript = pkgs.writeShellScript "patch-vscodium-node" ''
    echo "[patch-vscodium-node] Checking..."
    for dir in "$HOME/.vscodium-server/bin"/*; do
      if [ -f "$dir/node" ] && ! grep -q nixpkgs "$dir/node"; then
        echo "[patch-vscodium-node] Patching broken node in $dir"
        mv "$dir/node" "$dir/node.broken" || true
        echo '#!/usr/bin/env bash' > "$dir/node"
        echo 'exec ${nodejs}/bin/node "$@"' >> "$dir/node"
        chmod +x "$dir/node"
      fi
    done
  '';
in {
  environment.systemPackages = [ pkgs.nodejs ];

  systemd.user.services.fix-vscodium-node = {
    description = "Patch VSCodium's broken Node.js";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${nodeFixScript}";
    };
  };
}

# After trying to open a remote window into the NixOS machine, run this command and then it will work:
# systemctl --user start fix-vscodium-node.service