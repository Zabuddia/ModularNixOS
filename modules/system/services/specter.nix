{ scheme, host, port, lanPort, streamPort, expose, edgePort }:

{ config, lib, pkgs, ... }:
let
  extPort =
    if expose == "caddy-wan" then edgePort else lanPort;

  extPortSuffix =
    if extPort == null || extPort == 80 || extPort == 443
    then ""
    else ":${toString extPort}";

  externalURL = "${scheme}://${host}${extPortSuffix}";

  stateDir = "/var/lib/specter";
  venvDir  = "${stateDir}/.venv";

  specterRun = pkgs.writeShellScript "specter-run" ''
    set -euo pipefail

    export HOME="${stateDir}"
    export LD_LIBRARY_PATH="${pkgs.libusb1}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

    # Create venv if missing
    if [ ! -x "${venvDir}/bin/python" ]; then
      ${pkgs.python310}/bin/python -m venv "${venvDir}"
    fi

    . "${venvDir}/bin/activate"

    # Keep it close to what you tested in nix shell:
    pip install -U pip
    pip install "sqlalchemy<2.0" "flask-sqlalchemy<3.0"
    pip install cryptoadvance.specter

    # Bind locally (recommended if you're proxying with Caddy)
    exec python -m cryptoadvance.specter server \
      --host 127.0.0.1 \
      --port ${toString port}
  '';
in
{
  systemd.services.specter = {
    description = "Specter Server (cryptoadvance.specter)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    serviceConfig = {
      ExecStart = specterRun;
      Restart = "on-failure";
      RestartSec = 2;

      # Persistent state in /var/lib/specter (works well with DynamicUser)
      DynamicUser = true;
      StateDirectory = "specter";
      WorkingDirectory = stateDir;

      # Nice-to-haves
      Environment = [
        "PYTHONUNBUFFERED=1"
        # If Specter uses this (varies by version), you can keep it here:
        # "SPECTER_DATA_FOLDER=${stateDir}"
      ];
    };
  };

  # If you're reverse-proxying, this is the URL you usually want Specter to think it lives at.
  # Specter doesn’t strictly need this, but I’m leaving it here as a handy reference:
  # externalURL = "${externalURL}/";
}