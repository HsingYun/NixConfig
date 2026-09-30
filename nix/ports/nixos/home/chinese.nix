{ lib, software, ... }:
{
  software.requirements.fcitx5-rime = {
    capabilities = [ "store-package" ];
    scopes = [ ];
  };
  i18n.inputMethod = {
    enable = lib.mkDefault true;
    type = lib.mkDefault "fcitx5";
    fcitx5 = {
      waylandFrontend = lib.mkDefault true;
      addons = [ software.fcitx5-rime.package ];
    };
  };
  # The official session-bound user service is the sole Fcitx startup owner.
  xdg.configFile."autostart/org.fcitx.Fcitx5.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Fcitx 5
    Hidden=true
  '';
}
