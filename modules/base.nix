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
  time.timeZone = "America/Denver";
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
    nftables
    
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

    # media
    vlc yt-dlp ffmpeg

    # mDNS / .local resolution
    avahi
  ];

  ############################################
  ## Avahi
  ############################################
  services.avahi = {
    enable = true;
    # enable the NSS mDNS plugin so programs can resolve *.local names
    nssmdns4 = true;
    # optional: publish local hostname/address so others can find this machine
    publish = {
      enable = true;
      addresses = true;
      workstation = true;
    };
    # optional: open the firewall for Avahi if you're using the NixOS firewall
    # openFirewall = true;
  };

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
  ## State version (keep at first install’s release)
  ############################################
  system.stateVersion = "25.05";
}
