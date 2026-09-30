{ config, ... }:
{
  imports = [
    (import ../../../modules/home/integrations/gnome-chinese.nix {
      enabled = config.features.desktop.gnome.enable;
      extensionUuid = "kimpanel@kde.org";
    })
  ];
}
