{ lib, config, pkgs, hostDesktop, ... }:
let
  d = hostDesktop;

  validDesktops = [
    "gnome" "plasma" "cinnamon" "pantheon" "xfce"
    "lxqt" "budgie" "deepin" "enlightenment" "mate"
    "kodi" "headless"
  ];

  is = v: d == v;

  portalPkgs =
    if is "gnome" then [ pkgs.xdg-desktop-portal-gnome ]
    else if is "plasma" then [ pkgs.kdePackages.xdg-desktop-portal-kde ]
    else [ pkgs.xdg-desktop-portal-gtk ];

  portalDefault =
    if is "gnome" then "gnome"
    else if is "plasma" then "kde"
    else "gtk";
in
lib.mkMerge [
  {
    assertions = [
      { assertion = lib.elem d validDesktops;
        message = "hostDesktop must be one of ${lib.concatStringsSep ", " validDesktops}, got: ${toString d}";
      }
    ];

    xdg.portal = {
      enable = lib.mkDefault true;
      extraPortals = portalPkgs;
      config.common.default = [ portalDefault ];
    };
  }

  (lib.mkIf (is "gnome") {
    services.xserver.enable = true;
    services.displayManager.gdm.enable = true;
    services.desktopManager.gnome.enable = true;
  })

  (lib.mkIf (is "plasma") {
    services.xserver.enable = true;
    services.displayManager.sddm.enable = true;
    services.displayManager.sddm.wayland.enable = true;
    services.desktopManager.plasma6.enable = true;
  })

  (lib.mkIf (is "cinnamon") {
    services.xserver.enable = true;
    services.xserver.displayManager.lightdm.enable = true;
    services.xserver.desktopManager.cinnamon.enable = true;
  })

  (lib.mkIf (is "pantheon") {
    services.xserver.enable = true;
    services.xserver.displayManager.lightdm.enable = true;
    services.xserver.desktopManager.pantheon.enable = true;
  })

  (lib.mkIf (is "xfce") {
    services.xserver.enable = true;
    services.xserver.displayManager.lightdm.enable = true;
    services.xserver.desktopManager.xfce.enable = true;
  })

  (lib.mkIf (is "lxqt") {
    services.xserver.enable = true;
    services.displayManager.sddm.enable = true;
    services.xserver.desktopManager.lxqt.enable = true;
  })

  (lib.mkIf (is "budgie") {
    services.xserver.enable = true;
    services.xserver.displayManager.gdm.enable = true;
    services.xserver.desktopManager.budgie.enable = true;
  })

  (lib.mkIf (is "deepin") {
    services.xserver.enable = true;
    services.xserver.displayManager.lightdm.enable = true;
    services.xserver.desktopManager.deepin.enable = true;
  })

  (lib.mkIf (is "enlightenment") {
    services.xserver.enable = true;
    services.xserver.displayManager.lightdm.enable = true;
    services.xserver.desktopManager.enlightenment.enable = true;
  })

  (lib.mkIf (is "mate") {
    services.xserver.enable = true;
    services.xserver.displayManager.lightdm.enable = true;
    services.xserver.desktopManager.mate.enable = true;
  })

  (lib.mkIf (is "kodi") {
    services.xserver.enable = true;
    services.displayManager.defaultSession = "kodi";
    services.xserver.desktopManager.kodi.enable = true;
    services.xserver.desktopManager.kodi.package =
    pkgs.kodi-gbm.withPackages (kp: [
      kp.inputstream-adaptive
      kp.invidious
      kp.jellyfin
      kp.pvr-iptvsimple
      kp.pvr-hts
      kp.libretro-2048
    ]);

    # Optional: disable portals entirely
    xdg.portal.enable = lib.mkForce false;
  })

  (lib.mkIf (is "headless") {
    services.xserver.enable = lib.mkForce false;

    services.displayManager.gdm.enable = lib.mkForce false;
    services.displayManager.sddm.enable = lib.mkForce false;
    services.xserver.displayManager.lightdm.enable = lib.mkForce false;

    services.desktopManager.gnome.enable = lib.mkForce false;
    services.desktopManager.plasma6.enable = lib.mkForce false;
    services.xserver.desktopManager.cinnamon.enable = lib.mkForce false;
    services.xserver.desktopManager.pantheon.enable = lib.mkForce false;
    services.xserver.desktopManager.xfce.enable = lib.mkForce false;
    services.xserver.desktopManager.lxqt.enable = lib.mkForce false;
    services.xserver.desktopManager.budgie.enable = lib.mkForce false;
    services.xserver.desktopManager.deepin.enable = lib.mkForce false;
    services.xserver.desktopManager.enlightenment.enable = lib.mkForce false;
    services.xserver.desktopManager.mate.enable = lib.mkForce false;
    services.xserver.desktopManager.kodi.enable = lib.mkForce false;
  })
]