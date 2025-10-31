{ pkgs, ... }:
{
  programs.chromium = {
    enable = true;
    package = pkgs.ungoogled-chromium;
    commandLineArgs = [
      "--enable-features=UseOzonePlatform"
      "--ozone-platform=wayland"
    ];
    extensions = [
      {
        id = "cjpalhdlnbpafiamejdnhcphjbkeiagm";
        updateUrl = "https://clients2.google.com/service/update2/crx";
      }
    ];
  };
}