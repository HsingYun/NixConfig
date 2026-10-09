{
  config,
  lib,
  software,
  ...
}:
let
  cfg = config.i18n.inputMethod;
in
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
  # Suppress desktop autostart only while the systemd service owns startup.
  xdg.configFile."autostart/org.fcitx.Fcitx5.desktop" =
    lib.mkIf (cfg.enable && cfg.type == "fcitx5" && cfg.fcitx5.systemd.enable)
      {
        text = ''
          [Desktop Entry]
          Type=Application
          Name=Fcitx 5
          Hidden=true
        '';
      };
}
