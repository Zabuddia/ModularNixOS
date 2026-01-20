{ config, pkgs, ... }:

{
  ############################################
  ## Nix / flakes
  ############################################
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  ############################################
  ## Host basics
  ############################################
  i18n.defaultLocale = "en_US.UTF-8";

  ############################################
  ## Bootloader
  ############################################
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  ############################################
  ## Networking
  ############################################
  networking.networkmanager.enable = true;
  networking.networkmanager.wifi.powersave = false;

  ############################################
  ## Audio (PipeWire), printing, clipboard
  ############################################
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
  services.printing.enable = true;

  ############################################
  ## XKB defaults (desktop module will toggle X on/off)
  ############################################
  services.xserver.xkb.layout = "us";

  ############################################
  ## CLI + admin essentials
  ############################################
  environment.systemPackages = with pkgs; [
    # shell & editing
    nano

    # clipboard
    wl-clipboard xclip
    
    # networking & diag
    curl wget openssh rsync
    traceroute mtr bind netcat
    openssl inetutils swaks
    nftables mosquitto iperf
    ethtool socat wrk2 mitmproxy
    iw
    
    # process & files
    lsof file which
    coreutils-full findutils
    gawk gnused gnugrep gnutar
    gzip unzip zip p7zip
    sqlite
    
    # hardware info
    pciutils usbutils
    nvme-cli smartmontools
    parted

    # nix helpers
    nix-output-monitor nh
    nix-tree comma node2nix

    # secrets
    ssh-to-age sops

    # media
    vlc ffmpeg w_scan2
    v4l-utils libv4l gst_all_1.gstreamer
    alsa-utils
    
    # smart card tools
    pcsc-tools
    ccid
  ];

  ############################################
  ## Persistent journald logs
  ############################################
  services.journald.extraConfig = ''
    Storage=persistent
  '';

  ############################################
  ## Crash + power loss diagnostics
  ############################################
  boot.crashDump.enable = true;

  ############################################
  ## Upower
  ############################################
  services.upower.enable = true;
  
  ############################################
  ## Android
  ############################################
  programs.adb.enable = true;

  ############################################
  ## Smart cards
  ############################################
  services.pcscd.enable = true;
  hardware.gpgSmartcards.enable = true;
  services.udev.packages = [ pkgs.yubikey-personalization ];

  ############################################
  ## Nix-bitcoin Secrets
  ############################################
  nix-bitcoin.generateSecrets = true;

  ############################################
  ## Foreign binary loader (nix-ld) — for wheels like `tokenizers`
  ############################################
  programs.nix-ld = {
    enable = true;
    package = pkgs.nix-ld;
    libraries = with pkgs; [
      stdenv.cc.cc.lib  # libstdc++.so.6
      zlib              # libz.so
      openssl           # libssl.so, libcrypto.so
    ];
  };

  ############################################
  ## Swap file (8 GB)
  ############################################
  swapDevices = [
    { device = "/swapfile"; size = 8192; }
    # To make it encrypted if wanted
    # { device = "/swapfile"; size = 8192; randomEncryption = true; }
  ];

  ############################################
  ## State version (keep at first install’s release)
  ############################################
  system.stateVersion = "25.11";
}
