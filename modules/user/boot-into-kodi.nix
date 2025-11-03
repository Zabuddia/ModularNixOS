{ config, pkgs, ... }:
{
  xsession.initExtra = ''
    kodi &
  '';
}