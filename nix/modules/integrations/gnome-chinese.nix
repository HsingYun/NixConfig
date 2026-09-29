{
  config,
  lib,
  osConfig ? { },
  software,
  ...
}:
{
  imports = [ ../home/software ];
  config =
    lib.mkIf
      (
        (
          if config.software.platform == "arch" then
            config.features.desktop.gnome.enable
          else
            osConfig.services.desktopManager.gnome.enable
        )
        && (
          config.software.platform == "arch"
          || (config.i18n.inputMethod.enable && config.i18n.inputMethod.type == "fcitx5")
        )
      )
      {
        # Select at login, not when evaluating a machine with several desktops.
        # GNOME imports its login environment into the user service manager.
        home.sessionVariablesExtra = ''
          case ":''${XDG_CURRENT_DESKTOP-}:" in
            *:GNOME:*) export GTK_IM_MODULE="''${GTK_IM_MODULE-fcitx}" ;;
          esac
        '';
        software.requirements.gnome-kimpanel.capabilities = lib.optionals (
          config.software.platform != "arch"
        ) [ "store-package" ];
        dconf.settings = {
          "org/gnome/shell".enabled-extensions = [
            (
              if config.software.platform == "arch" then
                "kimpanel@kde.org"
              else
                software.gnome-kimpanel.package.extensionUuid
            )
          ];
          "org/gnome/settings-daemon/plugins/xsettings".overrides = [
            (lib.hm.gvariant.mkDictionaryEntry [
              "Gtk/IMModule"
              (lib.hm.gvariant.mkVariant "fcitx")
            ])
          ];
        };
      };
}
