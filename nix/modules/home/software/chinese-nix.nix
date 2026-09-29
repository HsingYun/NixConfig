{ lib, software, ... }:
{
  software.requirements.fcitx5-rime = {
    capabilities = [ "store-package" ];
    installNix = false;
  };
  i18n.inputMethod = {
    enable = lib.mkDefault true;
    type = lib.mkDefault "fcitx5";
    fcitx5 = {
      waylandFrontend = lib.mkDefault true;
      addons = [ software.fcitx5-rime.package ];
    };
  };
}
