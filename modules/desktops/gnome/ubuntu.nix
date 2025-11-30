{ pkgs, ... }:

{
  xdg.mimeApps = {
    enable = true;

    # The defaults GNOME should use:
    defaultApplications = {
      # Browser + URL schemes
      "text/html"               = [ "librewolf.desktop" ];
      "application/xhtml+xml"   = [ "librewolf.desktop" ];
      "application/x-www-browser" = [ "librewolf.desktop" ];
      "x-scheme-handler/http"   = [ "librewolf.desktop" ];
      "x-scheme-handler/https"  = [ "librewolf.desktop" ];
      "x-scheme-handler/about"  = [ "librewolf.desktop" ];
      "x-scheme-handler/unknown"= [ "librewolf.desktop" ];
      "x-scheme-handler/ftp"    = [ "librewolf.desktop" ];

      # Mail links
      "x-scheme-handler/mailto" = [ "org.gnome.Geary.desktop" ];

      # File manager
      "inode/directory"         = [ "org.gnome.Nautilus.desktop" ];

      # PDF
      "application/pdf"         = [ "librewolf.desktop" ];

      # Images (GNOME 45+ image viewer is Loupe)
      "image/jpeg"              = [ "org.gnome.Loupe.desktop" ];
      "image/png"               = [ "org.gnome.Loupe.desktop" ];
      "image/webp"              = [ "org.gnome.Loupe.desktop" ];
      "image/gif"               = [ "org.gnome.Loupe.desktop" ];

      # Video + audio
      "video/mp4"               = [ "vlc.desktop" ];
      "video/x-matroska"        = [ "vlc.desktop" ];
      "audio/mpeg"              = [ "vlc.desktop" ];
      "audio/flac"              = [ "vlc.desktop" ];

      # Text/code
      "text/plain"              = [ "org.gnome.TextEditor.desktop" ];
      "text/markdown"           = [ "marktext.desktop" ];
      "text/x-mimeapps-list"    = [ "org.gnome.TextEditor.desktop" ];
      "text/x-ini"              = [ "org.gnome.TextEditor.desktop" ];
      "application/x-desktop"   = [ "org.gnome.TextEditor.desktop" ];

      # Archives
      "application/zip"         = [ "org.gnome.FileRoller.desktop" ];
      "application/x-tar"       = [ "org.gnome.FileRoller.desktop" ];
      "application/x-7z-compressed" = [ "org.gnome.FileRoller.desktop" ];
    };
  };

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
        "bluebubbles.desktop"
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

    # Disable automatic screen blank
    "org/gnome/desktop/session" = {
      idle-delay = "uint32 0"; # 0 means "never"
    };

    # Disable automatic suspend (both on AC and battery)
    "org/gnome/settings-daemon/plugins/power" = {
      sleep-inactive-ac-type = "nothing";
      sleep-inactive-ac-timeout = "uint32 0";
      sleep-inactive-battery-type = "nothing";
      sleep-inactive-battery-timeout = "uint32 0";
    };
  };
  # Because idle-delay gets overwritten at login for some reason, we need to force it to 0 after login.
  systemd.user.services.force-idle-delay = {
    Unit = {
      Description = "Force idle-delay to 0 after GNOME login";
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.glib}/bin/gsettings set org.gnome.desktop.session idle-delay 0";
      Type = "oneshot";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
