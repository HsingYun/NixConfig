{ lib, pkgs, ... }:

{
  home.packages = with pkgs; [
    google-chrome
    vscode
    codex
  ];

  # Allow sensor-driven rotation outside GNOME's touch mode, including the lock screen.
  programs.gnome-shell.extensions = [
    { package = pkgs.gnomeExtensions.screen-rotate; }
  ];

  dconf.settings."org/gnome/settings-daemon/peripherals/touchscreen".orientation-lock =
    lib.mkDefault false;

  # Align sensor directions with the Pocket 4's landscape display orientation.
  dconf.settings."org/gnome/shell/extensions/screen-rotate".orientation-offset = lib.mkDefault 1;

  home.stateVersion = "26.05";
}
