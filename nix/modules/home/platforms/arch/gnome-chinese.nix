{ config, ... }:
{
  imports = [
    (import ../../../integrations/gnome-chinese.nix {
      enabled = config.features.desktop.gnome.enable;
      extensionUuid = "kimpanel@kde.org";
    })
  ];
}
