{ lib, software, ... }:
{
  programs = {
    gnome-shell = {
      enable = lib.mkDefault true;
      extensions = [ { package = software.gnome-screen-rotate.package; } ];
    };
  };
}
