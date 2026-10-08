{ config, lib, ... }:
{
  config =
    lib.mkIf
      (
        config.features.desktop.niri.enable
        && config.wayland.windowManager.niri.enable
        && config.features.chinese.enable
        && config.i18n.inputMethod.enable
        && config.i18n.inputMethod.type == "fcitx5"
      )
      {
        wayland.windowManager.niri.settings.environment = {
          # Do not inherit the GNOME session's GTK override: Niri uses the
          # compositor input-method protocol for candidate-window positioning.
          GTK_IM_MODULE = null;
          LANG = lib.mkIf (config.home.language.base != null) (lib.mkDefault config.home.language.base);
          XMODIFIERS = lib.mkIf (config.home.sessionVariables ? XMODIFIERS) (
            lib.mkDefault config.home.sessionVariables.XMODIFIERS
          );
        };
      };
}
