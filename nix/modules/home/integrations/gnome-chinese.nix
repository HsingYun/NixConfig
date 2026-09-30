{
  enabled,
  extensionUuid,
  capabilities ? [ ],
}:
{
  config,
  lib,
  ...
}:
{
  imports = [ ../software ];
  config = lib.mkIf enabled {
    # Select at login, not when evaluating a machine with several desktops.
    # GNOME imports its login environment into the user service manager.
    home.sessionVariablesExtra = ''
      case ":''${XDG_CURRENT_DESKTOP-}:" in
        *:GNOME:*) export GTK_IM_MODULE="''${GTK_IM_MODULE-fcitx}" ;;
      esac
    '';
    software.requirements.gnome-kimpanel = { inherit capabilities; };
    dconf.settings = {
      "org/gnome/shell".enabled-extensions = [ extensionUuid ];
      "org/gnome/settings-daemon/plugins/xsettings".overrides = [
        (lib.hm.gvariant.mkDictionaryEntry [
          "Gtk/IMModule"
          (lib.hm.gvariant.mkVariant "fcitx")
        ])
      ];
    };
  };
}
