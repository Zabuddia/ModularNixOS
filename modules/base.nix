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
    
    # networking & diag
    curl wget openssh rsync
    traceroute mtr nmap bind
    
    # process & files
    htop btop tmux lsof file which tree
    ripgrep fd jq coreutils-full findutils
    gawk gnused gnugrep gnutar
    gzip unzip zip p7zip
    
    # hardware info
    pcutils usbutils
    
    # nix helpers
    nix-output-monitor nh nix-index
    nix-tree comma fastfetch
  ];
  
  programs.nix-index = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
  }
  programs.command-not-found.enable = false;
  
  ############################################
  ## SSH agent
  ############################################
  programs.ssh.startAgent = true;
  
  ############################################
  ## Tailscale
  ############################################
  services.tailscale.enable = true;
  
  ############################################
  ## Containers
  ############################################
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
  }

  ############################################
  ## State version (keep at first install’s release)
  ############################################
  system.stateVersion = "25.05";
}
