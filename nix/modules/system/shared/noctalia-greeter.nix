{
  config,
  lib,
  ...
}:
let
  cfg = config.services.displayManager.noctalia-greeter;
  session = config.services.displayManager.defaultSession;
  wallpaper = config.features.desktop.wallpaper;
in
{
  services.displayManager.noctalia-greeter.settings = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.mkIf (session != null) { session.default = lib.mkDefault session; })
      (lib.mkIf (wallpaper.enable && wallpaper.lockImage != null) {
        appearance.wallpaper.path = lib.mkDefault (toString wallpaper.lockImage);
      })
    ]
  );
}
