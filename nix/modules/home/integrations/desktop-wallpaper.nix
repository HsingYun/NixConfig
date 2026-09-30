{
  config,
  options,
  lib,
  ...
}:
let
  cfg = config.features.desktop.wallpaper;
  image = cfg.image;
  lock = cfg.lockImage;
in
{
  dconf.settings = lib.mkIf config.programs.gnome-shell.enable {
    "org/gnome/desktop/background" = lib.mkIf (image != null) {
      picture-uri = lib.mkDefault "file://${image}";
      picture-uri-dark = lib.mkDefault "file://${image}";
      picture-options = lib.mkDefault "zoom";
    };
    "org/gnome/desktop/screensaver" = lib.mkIf (lock != null) {
      picture-uri = lib.mkDefault "file://${lock}";
    };
  };
  programs =
    (lib.optionalAttrs (options.programs ? dank-material-shell) {
      dank-material-shell = lib.mkIf config.programs.dank-material-shell.enable {
        session = lib.mkIf (image != null) {
          wallpaperPath = lib.mkDefault "${image}";
          wallpaperFillMode = lib.mkDefault "PreserveAspectCrop";
        };
        settings = lib.mkIf (lock != null) {
          lockScreenWallpaperPath = lib.mkDefault "${lock}";
          lockScreenWallpaperFillMode = lib.mkDefault "PreserveAspectCrop";
        };
      };
    })
    // lib.optionalAttrs (options.programs ? noctalia) {
      noctalia = lib.mkIf config.programs.noctalia.enable {
        settings = {
          wallpaper.default.path = lib.mkIf (image != null) (lib.mkDefault "${image}");
          lockscreen.wallpaper = lib.mkIf (lock != null) (lib.mkDefault "${lock}");
        };
      };
    };
}
