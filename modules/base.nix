{ config, pkgs, ... }:

{
  ############################################
  ## Nix / flakes
  ############################################
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

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
    nftables mosquitto
    
    # process & files
    lsof file which
    coreutils-full findutils
    gawk gnused gnugrep gnutar
    gzip unzip zip p7zip
    
    # hardware info
    pciutils usbutils
    
    # nix helpers
    nix-output-monitor nh
    nix-tree comma

    # secrets
    ssh-to-age sops

    # media
    vlc yt-dlp ffmpeg w_scan2
  ];

  ############################################
  ## Upower
  ############################################
  services.upower.enable = true;
  
  ############################################
  ## SSH agent
  ############################################
  programs.ssh.startAgent = true;
  
  ############################################
  ## Android
  ############################################
  programs.adb.enable = true;
  
  ############################################
  ## Containers
  ############################################
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
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
  system.stateVersion = "25.05";
}
