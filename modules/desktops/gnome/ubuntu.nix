{ pkgs, ... }:

{
  home.packages = with pkgs; [
    gnomeExtensions.dash-to-dock
    gnomeExtensions.start-overlay-in-application-view
    gnomeExtensions.no-overview
    gnomeExtensions.appindicator
  ];

  dconf.settings = {
    "org/gnome/shell" = {
    enabled-extensions = [
      "dash-to-dock@micxgx.gmail.com"
      "start-overlay-in-application-view@Hex_cz"
      "no-overview@fthx"
      "appindicatorsupport@rgcjonas.gmail.com"
    ];
  };

    # Configure dock
    "org/gnome/shell/extensions/dash-to-dock" = {
      dock-position = "LEFT";
      dock-fixed = true;
      extend-height = true;
      click-action = "minimize-or-previews";
      running-indicator-style = "DOTS";
      running-indicator-dominant-color = true;
    };

    # Turn on night light
    "org/gnome/settings-daemon/plugins/color" = {
      night-light-enabled = true;
      night-light-schedule-automatic = true;
    };
    
    # Pin apps to dock
    "org/gnome/shell" = {
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
    
    # Custom shortcut to open the Console
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      name = "Launch GNOME Console";
      binding = "<Control><Alt>T";
      command = "kgx";
    };
    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = ["/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"];
    };
    
    # Get the minimize and maximize buttons back
    "org/gnome/desktop/wm/preferences" = {
      button-layout = ":minimize,maximize,close";
    };
    
    # Make it so windows snap into place and dynamic workspaces and only primary display changes workspaces
    "org/gnome/mutter" = {
      edge-tiling = true;
      dynamic-workspaces = true;
      workspaces-only-on-primary = true;
    };
    
    # Make it show the battery percentage
    "org/gnome/desktop/interface" = {
      show-battery-percentage = true;
    };
  };
}
