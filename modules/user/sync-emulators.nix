{ config, lib, pkgs, ... }:

let
  # All emulator data will live in: ~/Sync/EmuSaves/<name>/
  baseDir = "${config.home.homeDirectory}/Sync/EmuSaves";

  # Add more emulators by appending lines here:
  #   name = "path/inside/$HOME/where/emulator/keeps/data";
  # Examples to uncomment later:
  #   melonds = ".local/share/melonds";
  #   dolphin = ".local/share/dolphin-emu";
  #   ryujinx = ".config/Ryujinx";
  emuDirs = {
    azahar = ".local/share/azahar-emu";
  };

  names = builtins.attrNames emuDirs;
in
{
  # (Optional) install the emulator; comment out if you prefer
  home.packages = with pkgs; [ azahar ];

  # One-time migrate + always symlink each emulator’s data into ~/Sync/EmuSaves/<name>
  home.activation.emuSync = lib.hm.dag.entryAfter [ "writeBoundary" ] (
    lib.concatStringsSep "\n" (map (name: ''
      mkdir -p ${lib.escapeShellArg baseDir}/${name}
      if [ -e ${lib.escapeShellArg config.home.homeDirectory}/${emuDirs.${name}} ] \
           && [ ! -L ${lib.escapeShellArg config.home.homeDirectory}/${emuDirs.${name}} ]; then
        echo "[emu-sync] Migrating ${config.home.homeDirectory}/${emuDirs.${name}} -> ${baseDir}/${name}"
        rsync -a --remove-source-files \
          "${config.home.homeDirectory}/${emuDirs.${name}}/" \
          "${baseDir}/${name}/" || true
        rmdir -p --ignore-fail-on-non-empty \
          "${config.home.homeDirectory}/${emuDirs.${name}}" 2>/dev/null || true
      fi
      mkdir -p "$(dirname ${lib.escapeShellArg config.home.homeDirectory}/${emuDirs.${name}})"
      ln -sfn "${baseDir}/${name}" "${config.home.homeDirectory}/${emuDirs.${name}}"
    '') names)
  );

  # Keep HM aware of the links so they persist cleanly across rebuilds.
  home.file = lib.mkMerge (map (name: {
    "${emuDirs.${name}}".source = "${baseDir}/${name}";
    "${emuDirs.${name}}".recursive = true;
    "${emuDirs.${name}}".force = true;
  }) names);

  # Minimal Syncthing: one folder for all emu saves (add devices in your main config later)
  services.syncthing = {
    enable = true;
    settings.folders."EmuSaves" = {
      path = baseDir;
      fsWatcherEnabled = true;
      ignorePerms = true;
    };
  };
}