{
  config,
  lib,
  pkgs,
  user,
  ...
}:
let
  wallpaper = config.home-manager.users.${user.username}.features.desktop.wallpaper;
  lock = wallpaper.lockImage;
  session = pkgs.writeTextDir "session.json" (
    builtins.toJSON {
      wallpaperPath = toString lock;
      wallpaperFillMode = "PreserveAspectCrop";
    }
  );
  settings = pkgs.writeTextDir "settings.json" (
    builtins.toJSON {
      lockScreenWallpaperPath = toString lock;
      lockScreenWallpaperFillMode = "PreserveAspectCrop";
    }
  );
in
{
  # The greeter runs before login, so use a system-readable copy of the settings.
  services.displayManager.dms-greeter.configFiles =
    lib.mkIf (config.services.displayManager.dms-greeter.enable && lock != null)
      [
        "${session}/session.json"
        "${settings}/settings.json"
      ];
}
