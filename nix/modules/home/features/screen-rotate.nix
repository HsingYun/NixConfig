{ lib, software, ... }:
{
  programs.gnome-shell.enable = lib.mkDefault true;
  programs.gnome-shell.extensions = [ { package = software.gnome-screen-rotate.package; } ];
}
