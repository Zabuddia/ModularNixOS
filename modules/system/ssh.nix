{ config, lib, pkgs, ... }:

{
  services.openssh = {
    enable = true;          # start the SSH server (sshd)
    openFirewall = false;    # open TCP 22 in the firewall
    # settings = {
    #   PermitRootLogin = "no";
    #   PasswordAuthentication = false;  # keys only (recommended)
    #   KbdInteractiveAuthentication = false;
    # };
  };

  # Optional: change the port
  # networking.firewall.allowedTCPPorts = [ 2222 ];
  # services.openssh.ports = [ 2222 ];

  # Optional: add an authorized key for a user
  # users.users.buddia.openssh.authorizedKeys.keys = [
  #   "ssh-ed25519 AAAA... yourkey"
  # ];
}