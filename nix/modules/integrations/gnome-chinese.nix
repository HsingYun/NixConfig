{
  config,
  lib,
  pkgs,
  osConfig,
  ...
}:
{
  config =
    lib.mkIf
      (
        osConfig.services.desktopManager.gnome.enable
        && config.i18n.inputMethod.enable
        && config.i18n.inputMethod.type == "fcitx5"
      )
      {
        home.packages = [ pkgs.gnomeExtensions.kimpanel ];
        dconf.settings = {
          "org/gnome/shell".enabled-extensions = [ pkgs.gnomeExtensions.kimpanel.extensionUuid ];
          "org/gnome/settings-daemon/plugins/xsettings".overrides = [
            (lib.hm.gvariant.mkDictionaryEntry [
              "Gtk/IMModule"
              (lib.hm.gvariant.mkVariant "fcitx")
            ])
          ];
        };
      };
}
