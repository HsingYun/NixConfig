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
    # NixOS GNOME supplies ibus globally. Its GTK bridge loses candidate-window
    # positioning with Fcitx, so replace that default as well as an unset value.
    home.sessionVariablesExtra = ''
      case ":''${XDG_CURRENT_DESKTOP-}:" in
        *:GNOME:*)
          case "''${GTK_IM_MODULE-}" in
            ""|ibus) export GTK_IM_MODULE=fcitx ;;
          esac
          ;;
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
