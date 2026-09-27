{
  lib,
  pkgs,
  ...
}:

{
  imports = [ ../shared/desktop.nix ];
  services.desktopManager.gnome.enable = lib.mkDefault true;

  environment.gnome.excludePackages = with pkgs; [
    baobab
    decibels
    epiphany
    gnome-calculator
    gnome-calendar
    gnome-clocks
    gnome-color-manager
    gnome-connections
    gnome-console
    gnome-contacts
    gnome-maps
    gnome-music
    gnome-software
    gnome-tecla
    gnome-tour
    gnome-weather
    orca
    showtime
    simple-scan
    sushi
  ];
}
