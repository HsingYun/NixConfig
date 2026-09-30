{
  config,
  osConfig,
  software,
  ...
}:
{
  imports = [
    (import ../../../integrations/gnome-chinese.nix {
      enabled =
        osConfig.services.desktopManager.gnome.enable
        && config.i18n.inputMethod.enable
        && config.i18n.inputMethod.type == "fcitx5";
      extensionUuid = software.gnome-kimpanel.package.extensionUuid;
      capabilities = [ "store-package" ];
    })
  ];
}
