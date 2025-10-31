# melonds-config.nix
{ config, lib, pkgs, ... }:

let
  home = config.home.homeDirectory;
  base = "${home}/.local/share/melonDS";

  seedToml = pkgs.writeText "melonDS.toml" ''
    UITheme = ""
    RecentROM = []
    FastForwardFPS = 1000.0
    AudioSync = false
    PauseLostFocus = false
    TargetFPS = 60.0
    LimitFPS = true
    SlowmoFPS = 30.0

    [Mouse]
    Hide = false
    HideSeconds = 5

    [DSi]
    NANDPath = ""

    [DSi.Camera1]
    DeviceName = ""
    ImagePath = ""
    InputType = 0
    XFlip = false

    [DSi.Camera0]
    DeviceName = ""
    ImagePath = ""
    InputType = 0
    XFlip = false

    [3D]
    Renderer = 0

    [MP]
    AudioMode = 1
    RecvTimeout = 25

    [Savestate]
    RelocSRAM = false

    [LAN]
    DirectMode = false

    [Instance0]
    CheatFilePath = "${base}/cheats"
    SavestatePath = "${base}/states"
    JoystickID = 0
    SaveFilePath = "${base}/saves"
    EnableCheats = false

    [Instance0.Window1]
    Enabled = false

    [Instance0.Window3]
    Enabled = false

    [Instance0.Joystick]
    HK_SlowMoToggle = -1
    HK_Lid = -1
    Y = -1
    HK_FrameStep = -1
    HK_SolarSensorIncrease = -1
    L = -1
    R = -1
    Up = -1
    HK_FullscreenToggle = -1
    HK_SlowMo = -1
    HK_Pause = -1
    Right = -1
    Start = -1
    Select = -1
    X = -1
    B = -1
    Down = -1
    A = -1
    HK_Mic = -1
    HK_FastForward = -1
    HK_FrameLimitToggle = -1
    Left = -1
    HK_SwapScreens = -1
    HK_SwapScreenEmphasis = -1
    HK_Reset = -1
    HK_PowerButton = -1
    HK_VolumeDown = -1
    HK_SolarSensorDecrease = -1
    HK_VolumeUp = -1
    HK_FastForwardToggle = -1

    [Instance0.Window2]
    Enabled = false

    [Instance0.Keyboard]
    HK_SlowMoToggle = -1
    HK_Lid = -1
    Y = -1
    HK_FrameStep = -1
    HK_SolarSensorIncrease = -1
    L = -1
    R = -1
    Up = -1
    HK_FullscreenToggle = -1
    HK_SlowMo = -1
    HK_Pause = -1
    Right = -1
    Start = -1
    Select = -1
    X = -1
    B = -1
    Down = -1
    A = -1
    HK_Mic = -1
    HK_FastForward = -1
    HK_FrameLimitToggle = -1
    Left = -1
    HK_SwapScreens = -1
    HK_SwapScreenEmphasis = -1
    HK_Reset = -1
    HK_PowerButton = -1
    HK_VolumeDown = -1
    HK_SolarSensorDecrease = -1
    HK_VolumeUp = -1
    HK_FastForwardToggle = -1

    [Instance0.Audio]
    DSiVolumeSync = false
    Volume = 256

    [Instance0.Firmware]
    Username = "melonDS"

    [Instance0.Window0]
    ScreenFilter = false
    ScreenAspectTop = 0
    IntegerScaling = false
    ScreenSizing = 0
    ScreenSwap = false
    ScreenGap = 0
    ScreenAspectBot = 0
    ScreenRotation = 0
    ScreenLayout = 0
    Geometry = ""
    ShowOSD = true

    [Emu]
    ConsoleType = 0

    [Screen]
    UseGL = false

    [Mic]
    WavPath = ""
    Device = ""
    InputType = 1
  '';
in {
  # Make sure the local save/state/cheat dirs exist
  home.activation.createMelondsDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "${base}/saves" "${base}/states" "${base}/cheats"
  '';

  # Seed a writable TOML once (don't overwrite user changes later)
  home.activation.copyMelondsConfig = lib.hm.dag.entryAfter [ "createMelondsDirs" ] ''
    mkdir -p "${config.xdg.configHome}/melonDS"
    if [ ! -e "${config.xdg.configHome}/melonDS/melonDS.toml" ]; then
      cp ${seedToml} "${config.xdg.configHome}/melonDS/melonDS.toml"
      chmod u+w "${config.xdg.configHome}/melonDS/melonDS.toml"
    fi
  '';
}