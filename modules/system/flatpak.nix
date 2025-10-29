{ pkgs, ... }:

{
  services.flatpak.enable = true;

  systemd.services.add-flathub = {
    description = "Add Flathub Flatpak remote";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    serviceConfig = {
      Type = "oneshot";
      # IMPORTANT: system scope + reliable CDN endpoint
      ExecStart = ''
        ${pkgs.flatpak}/bin/flatpak --system remote-add --if-not-exists \
          flathub https://dl.flathub.org/repo/flathub.flatpakrepo
      '';
      TimeoutStartSec = "10min";   # allow for slow networks
      Restart = "on-failure";      # auto-retry if network was late
      RestartSec = "30s";
    };
  };
}