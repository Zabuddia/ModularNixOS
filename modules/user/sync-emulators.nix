{ config, pkgs, lib, ... }:

let
  home    = config.home.homeDirectory;
  baseDir = "${home}/Sync/EmulatorSaves";

  # List of emulators to sync. Add new ones here.
  # local = path under $HOME where the emulator expects its data
  # sync  = subfolder name under ~/Sync/EmulatorSaves
  emulators = [
    { local = ".local/share/azahar-emu";  sync = "azahar-emu"; }
    { local = ".local/share/dolphin-emu"; sync = "dolphin-emu"; }
    { local = ".local/share/melonDS"; sync = "melonDS"; }
    { local = ".config/Ryujinx/bis/user/save"; sync = "Ryujinx"; }
    # Example:
    # { local = ".config/retroarch"; sync = "retroarch"; }
  ];

  # helper: make out-of-store symlink under $HOME
  mkLink = { localPath, syncPath }: {
    name = localPath;  # key is path relative to $HOME
    value = {
      source = config.lib.file.mkOutOfStoreSymlink syncPath;
      recursive = true;
      force = true;
    };
  };

  # Build the home.file attrs from the list
  links = builtins.map
    (e: mkLink {
      localPath = e.local;
      syncPath  = "${baseDir}/${e.sync}";
    })
    emulators;

  # Shell lines to ensure each target sync dir exists
  mkDirsScript =
    lib.concatStringsSep "\n"
      (map (e: ''mkdir -p "${baseDir}/${e.sync}"'') emulators);

in {
  ################
  # Your modules
  ################
  imports = [
    ./unstable/dolphin-emu.nix
    ./melonds.nix
  ];

  ################
  # User packages
  ################
  home.packages = with pkgs; [
    ryubing
    azahar
    syncthing
  ];

  #############################
  # Ensure directories exist
  #############################
  home.activation.createSyncDirs =
    lib.hm.dag.entryAfter [ "writeBoundary" ] mkDirsScript;

  #########################
  # Symlinks into ~/Sync
  #########################
  home.file = builtins.listToAttrs links;

  ########################################
  # Syncthing (user service) + one folder
  ########################################
  services.syncthing = {
    enable = true;
    tray.enable = true;
    settings.folders."EmulatorSaves" = {
      label = "EmulatorSaves";
      path = baseDir;
      fsWatcherEnabled = true;
      ignorePerms = true;
    };
  };
}