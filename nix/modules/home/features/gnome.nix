{ lib, pkgs, ... }:

{
  imports = [ ../shared/desktop.nix ];

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
