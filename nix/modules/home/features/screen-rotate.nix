{
  config,
  lib,
  software,
  ...
}:
{
  dconf.settings."org/gnome/shell/extensions/screen-rotate" =
    config.features.desktop.screenRotate.settings;
  programs = {
    gnome-shell = {
      enable = lib.mkDefault true;
      extensions = [ { package = software.gnome-screen-rotate.package; } ];
    };
  };
}
