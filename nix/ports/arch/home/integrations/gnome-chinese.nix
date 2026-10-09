{ config, osConfig, ... }:
{
  imports = [
    (import ../../../../modules/home/integrations/gnome-chinese.nix {
      enabled =
        osConfig.services.desktopManager.gnome.enable
        && config.i18n.inputMethod.enable
        && config.i18n.inputMethod.type == "fcitx5";
      extensionUuid = "kimpanel@kde.org";
    })
  ];
}
