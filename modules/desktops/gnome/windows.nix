{ pkgs, ... }:
{
  # Extensions for a Windows-like layout
  home.packages = with pkgs; [
    gnomeExtensions.dash-to-panel   # merges top bar + dock into a bottom taskbar
    gnomeExtensions.arcmenu         # Windows-style Start menu
  ];

  dconf.settings = {
    # Enable extensions + pin your favorite apps
    "org/gnome/shell" = {
      enabled-extensions = [
        "dash-to-panel@jderose9.github.com"
        "arcmenu@arcmenu.com"
      ];

      favorite-apps = [
        "codium.desktop"
        "librewolf.desktop"
        "sparrow-desktop.desktop"
        "org.remmina.Remmina.desktop"
        "org.gnome.TextEditor.desktop"
        "org.gnome.Console.desktop"
        "org.gnome.Nautilus.desktop"
        "org.gnome.Calculator.desktop"
        "org.gnome.Settings.desktop"
      ];
    };

    # Dash-to-Panel: bottom taskbar, show desktop button, global task list
    "org/gnome/shell/extensions/dash-to-panel" = {
      panel-position = "BOTTOM";
      panel-size = 36;
      stockgs-keep-top-panel = false;
      show-showdesktop-button = true;
      isolate-workspaces = false; # Windows-like: show all windows
      animate-appicon-hover = true;
      appicon-margin = 4;
      tray-margin-left = 8;
      # Common click action: cycle through windows of the app
      click-action = "CYCLE-WINDOWS";
    };

    # ArcMenu: Windows-style Start menu
    "org/gnome/shell/extensions/arcmenu" = {
      menu-layout = "Windows";
      panel-button-text = "Start";
      show-user-avatar = false;
      hot-corners = false;
      # You can try binding Super to ArcMenu (may vary by version):
      # hotkey = "Super_L";
    };

    # Night Light like your Ubuntu-style setup
    "org/gnome/settings-daemon/plugins/color" = {
      night-light-enabled = true;
      night-light-schedule-automatic = true;
    };

    # Console shortcut (Ctrl+Alt+T)
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      name = "Launch GNOME Console";
      binding = "<Control><Alt>T";
      command = "kgx";
    };
    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
      ];
    };

    # Titlebar buttons like Windows
    "org/gnome/desktop/wm/preferences" = {
      button-layout = ":minimize,maximize,close";
    };

    # Snap/tiling & workspace behavior
    "org/gnome/mutter" = {
      edge-tiling = true;
      dynamic-workspaces = true;
      workspaces-only-on-primary = true;
    };

    # Show battery percent
    "org/gnome/desktop/interface" = {
      show-battery-percentage = true;
    };
  };
}
