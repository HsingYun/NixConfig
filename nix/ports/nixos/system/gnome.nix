{
  lib,
  pkgs,
  ...
}:

{
  imports = [ ./desktop-nixos.nix ];
  services.desktopManager.gnome.enable = lib.mkDefault true;

  environment.gnome.excludePackages = with pkgs; [
    baobab
    decibels
    epiphany
    gnome-calculator
    gnome-calendar
    gnome-clocks
    gnome-connections
    # Ghostty supplies the terminal; Text Editor and Snapshot replace legacy apps.
    gnome-console
    gnome-terminal
    gedit
    cheese
    gnome-contacts
    gnome-maps
    gnome-music
    gnome-software
    gnome-tecla
    gnome-tour
    gnome-weather
    # The shared desktop.fileManager feature owns the file manager package.
    nautilus
    orca
    showtime
    simple-scan
  ];
}
