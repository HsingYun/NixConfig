{
  config,
  lib,
  ...
}:

{
  imports = [
    ../shared/desktop.nix
  ];

  programs.dank-material-shell = {
    enable = lib.mkDefault true;
    systemd.enable = lib.mkDefault false;

    inherit (config.features.desktop.dms) settings session;
    enableCalendarEvents = lib.mkDefault false;
  };
}
