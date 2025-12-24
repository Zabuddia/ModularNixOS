{ scheme, host, port, lanPort, streamPort, expose, edgePort }:

{ config, lib, pkgs, ... }:
let
  stateDir = "/var/lib/specter";
  venvDir  = "${stateDir}/.venv";

  specterRun = pkgs.writeShellScriptBin "specter-run" ''
    set -euo pipefail

    export HOME="${stateDir}"
    export LD_LIBRARY_PATH="${pkgs.libusb1}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

    if [ ! -x "${venvDir}/bin/python" ]; then
      ${pkgs.python310}/bin/python -m venv "${venvDir}"
    fi

    . "${venvDir}/bin/activate"

    pip install -U pip
    pip install "sqlalchemy<2.0" "flask-sqlalchemy<3.0"
    pip install cryptoadvance.specter

    exec python -m cryptoadvance.specter server \
      --host 127.0.0.1 \
      --port ${toString port}
  '';
in
{
  users.groups.specter = { };
  users.users.specter = {
    isSystemUser = true;
    group = "specter";
    home = stateDir;
    createHome = true;
  };

  systemd.services.specter = {
    description = "Specter Server (cryptoadvance.specter)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    serviceConfig = {
      User = "specter";
      Group = "specter";
      WorkingDirectory = stateDir;

      ExecStart = "${specterRun}/bin/specter-run";
      Restart = "on-failure";
      RestartSec = 2;

      # keep persistent state directory, but now owned by specter
      StateDirectory = "specter";
      Environment = [ "PYTHONUNBUFFERED=1" ];
    };
  };
}
