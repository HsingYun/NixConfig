{
  lib,
  software,
  user,
  ...
}:

{
  imports = [ ../shared/desktop.nix ];

  software.requirements =
    lib.genAttrs
      [
        "gnome-firmware"
        "gnome-user-themes"
        "gnome-dash-to-dock"
        "gnome-desktop-icons"
      ]
      (_: {
        capabilities = [ "store-package" ];
      });

  # GNOME's native lock screen uses the desktop background.
  dconf.settings."org/gnome/desktop/background" = lib.mkIf ((user.wallpaper or null) != null) {
    picture-uri = lib.mkDefault "file://${user.wallpaper}";
    picture-uri-dark = lib.mkDefault "file://${user.wallpaper}";
    picture-options = lib.mkDefault "zoom";
  };

  programs.gnome-shell = {
    enable = lib.mkDefault true;
    extensions = map (package: { inherit package; }) ([
      software.gnome-user-themes.package
      software.gnome-dash-to-dock.package
      software.gnome-desktop-icons.package
    ]);
  };

  xdg.userDirs = {
    enable = lib.mkDefault true;
    createDirectories = lib.mkDefault true;
  };
}
