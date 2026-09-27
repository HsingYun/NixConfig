{ lib, ... }:

{
  imports = [ ../shared/desktop.nix ];
  programs.niri.enable = lib.mkDefault true;
  programs.dms-shell = {
    enable = lib.mkDefault true;
    systemd.enable = lib.mkDefault true;
    systemd.target = lib.mkDefault "niri.service";
    enableCalendarEvents = lib.mkDefault false;
  };
  security.pam.services.dankshell = { };
}
