{ lib, pkgs, hostDesktop, ... }:

let
  isGnome  = hostDesktop == "gnome";
  isPlasma = hostDesktop == "plasma";
in
{
  config = lib.mkMerge [

    # GNOME: user-session screen sharing (Wayland-ready)
    (lib.mkIf isGnome {
      systemd.services."gnome-remote-desktop".wantedBy = [ "graphical.target" ];
    })

    # Plasma (Wayland): KRdp shares the current session
    (lib.mkIf isPlasma {
      environment.systemPackages = [ pkgs.kdePackages.krdp ];
    })

    # Fallback for other desktops: xrdp (separate login session)
    (lib.mkIf (!(isGnome || isPlasma)) {
      services.xrdp.enable = true;
    })
  ];
}
