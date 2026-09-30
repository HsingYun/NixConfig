{ lib, ... }: {
  options.services.desktopManager.gnome.enable = lib.mkEnableOption "GNOME";
  options.services.displayManager.gdm.enable = lib.mkEnableOption "GDM";
}
