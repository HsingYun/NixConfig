{
  lib,
  pkgs,
  user,
  ...
}:

{
  imports = [ ../shared/desktop.nix ];

  home.packages = [ pkgs.gnome-firmware ];

  # GNOME's native lock screen uses the desktop background.
  dconf.settings."org/gnome/desktop/background" = lib.mkIf ((user.wallpaper or null) != null) {
    picture-uri = lib.mkDefault "file://${user.wallpaper}";
    picture-uri-dark = lib.mkDefault "file://${user.wallpaper}";
    picture-options = lib.mkDefault "zoom";
  };

  programs.gnome-shell = {
    enable = lib.mkDefault true;
    extensions = map (package: { inherit package; }) (
      with pkgs.gnomeExtensions;
      [
        user-themes
        dash-to-dock
        desktop-icons-ng-ding
      ]
    );
  };

  xdg.userDirs = {
    enable = lib.mkDefault true;
    createDirectories = lib.mkDefault true;
  };
}
