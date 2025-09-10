{ pkgs, lib, ... }:
{
  xdg.configFile = {

    # Global KDE/Plasma look & behavior
    "kdeglobals".text = ''
[General]
ColorScheme=Breeze Dark
widgetStyle=Breeze

[Icons]
Theme=Breeze

[KDE]
SingleClick=false

[Toolbar style]
ToolButtonStyle=ToolButtonTextBesideIcon

[WM]
activeBackground=31,31,31
    '';

    # KWin window manager tweaks
    "kwinrc".text = ''
[Windows]
BorderlessMaximizedWindows=true

[TabBox]
LayoutName=thumbnail

[Plugins]
blurEnabled=true
contrastEnabled=true
    '';

    # Plasma theme + misc
    "plasmarc".text = ''
[Theme]
name=BreezeDark

[Wallpapers]
usersWallpapers=/usr/share/wallpapers
    '';

    # Keyboard shortcuts (example: Console on Ctrl+Alt+T)
    "kglobalshortcutsrc".text = ''
[konsole]
_new_instance=Ctrl+Alt+T,none,Open Konsole

[ksmserver]
Lock Session=Meta+L,Meta+L,Lock Session
    '';

    # ----- Panel & pinned apps (Icon Tasks) -----
    # Minimal, opinionated example: bottom panel with Kickoff + Icon Tasks
    # NOTE: Plasma will expand this file a lot on first run; keep this as a seed.
    "plasma-org.kde.plasma.desktop-appletsrc".text = ''
[General]
# One default activity
[Containments][1]
activityId=
formfactor=2
location=bottom
plugin=org.kde.plasma.panel
immutability=1

# Kickoff launcher (Start menu)
[Containments][1][Applets][2]
immutability=1
plugin=org.kde.plasma.kickoff

# Icon Tasks with your favorites (Windows-like taskbar)
[Containments][1][Applets][3]
immutability=1
plugin=org.kde.plasma.icontasks

[Containments][1][Applets][3][Configuration]
PreloadWeight=100

# Pinned launchers — map to your favorites
# (use `applications:<desktop-file>` entries)
[Containments][1][Applets][3][Configuration][General]
launchers=\
applications:codium.desktop,\
applications:librewolf.desktop,\
applications:sparrow-desktop.desktop,\
applications:org.remmina.Remmina.desktop,\
applications:org.kde.kate.desktop,\
applications:org.kde.konsole.desktop,\
applications:org.kde.dolphin.desktop,\
applications:org.kde.kcalc.desktop,\
applications:systemsettings.desktop

# System Tray
[Containments][1][Applets][4]
immutability=1
plugin=org.kde.plasma.systemtray

# Geometry hints — Plasma will adjust these after first login
[Containments][1][General]
alignment=0
    '';

    # Optional: GTK theming to match
    "kde-gtk-configrc".text = ''
[Settings]
gtk-theme-name=Breeze-Dark
gtk-icon-theme-name=Breeze
    '';
  };

  # Nice-to-have: restart Plasma automatically when this file changes during switch.
  # (Harmless if plasmashell isn’t running.)
  home.activation.restartPlasma = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if command -v kquitapp6 >/dev/null 2>&1; then
      kquitapp6 plasmashell || true
      (plasmashell & disown) || true
    fi
  '';
}
