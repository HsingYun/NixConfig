{
  lib,
  pkgs,
  user,
  ...
}:

let
  greeterSession = pkgs.writeTextDir "session.json" (
    builtins.toJSON {
      wallpaperPath = "${user.lockWallpaper}";
      wallpaperFillMode = "PreserveAspectCrop";
    }
  );
  greeterSettings = pkgs.writeTextDir "settings.json" (
    builtins.toJSON {
      lockScreenWallpaperPath = "${user.lockWallpaper}";
      lockScreenWallpaperFillMode = "PreserveAspectCrop";
    }
  );
in
{
  imports = [ ../shared/desktop.nix ];
  programs.niri.enable = lib.mkDefault true;
  programs.dms-shell = {
    enable = lib.mkDefault true;
    systemd.enable = lib.mkDefault true;
    systemd.target = lib.mkDefault "niri.service";
    enableCalendarEvents = lib.mkDefault false;
  };
  security.pam.services.dankshell = { };

  # Greeter defaults are available before the user's first login.
  services.displayManager.dms-greeter.configFiles = lib.mkIf ((user.lockWallpaper or null) != null) [
    "${greeterSession}/session.json"
    "${greeterSettings}/settings.json"
  ];
}
