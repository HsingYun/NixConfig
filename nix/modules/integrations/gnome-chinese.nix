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
        # Select at login, not when evaluating a machine with several desktops.
        # GNOME imports its login environment into the user service manager.
        home.sessionVariablesExtra = ''
          case ":''${XDG_CURRENT_DESKTOP-}:" in
            *:GNOME:*) export GTK_IM_MODULE="''${GTK_IM_MODULE-fcitx}" ;;
          esac
        '';
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
