{ pkgs, ... }:

{
  services.flatpak.enable = true;

  # Add Flathub remote on boot (runs once if not already added)
  systemd.services.add-flathub = {
    description = "Add Flathub Flatpak remote";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.flatpak}/bin/flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo";
    };
  };
}