{
  inputs,
  lib,
  pkgs,
  user,
  ...
}:

{
  imports = [
    inputs.dms.homeModules.dank-material-shell
    ../shared/desktop.nix
  ];

  programs.dank-material-shell = {
    enable = lib.mkDefault true;
    package = lib.mkDefault pkgs.dms-shell;
    enableCalendarEvents = lib.mkDefault false;
    # NixOS owns the service; Home Manager owns declarative configuration.
    systemd.enable = lib.mkDefault false;

    # Upstream manages each nonempty settings/session attribute set as a read-only file.
    session = lib.mkIf ((user.wallpaper or null) != null) {
      wallpaperPath = lib.mkDefault "${user.wallpaper}";
      wallpaperFillMode = lib.mkDefault "PreserveAspectCrop";
    };
    settings = lib.mkIf ((user.lockWallpaper or null) != null) {
      lockScreenWallpaperPath = lib.mkDefault "${user.lockWallpaper}";
      lockScreenWallpaperFillMode = lib.mkDefault "PreserveAspectCrop";
    };
  };
}
