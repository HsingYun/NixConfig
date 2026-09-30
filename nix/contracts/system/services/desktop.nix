{ lib, ... }: {
  options = {
    programs.niri.enable = lib.mkEnableOption "Niri";
    programs.dms-shell.enable = lib.mkEnableOption "DMS";
    services.desktopManager.gnome.enable = lib.mkEnableOption "GNOME";
  };
}
