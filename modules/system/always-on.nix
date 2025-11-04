{ ... }:

{
  services.logind.extraConfig = ''
    IdleAction=ignore
    IdleActionSec=0
  '';
}