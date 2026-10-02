{
  config,
  lib,
  ...
}:
{
  imports = [ ../shared/desktop.nix ];

  software.requirements = lib.genAttrs [
    "gnome-system-monitor"
    "gnome-text-editor"
    "snapshot"
    "gnome-user-themes"
    "gnome-dash-to-dock"
    "gnome-desktop-icons"
  ] (_: { });
  dconf.settings = lib.mkMerge [
    config.features.desktop.gnome.settings
    {
      "org/gnome/desktop/app-folders" = lib.mkIf config.features.desktop.gnome.flatAppGrid {
        # An explicit empty user value also prevents Shell from creating its
        # default folders. Preserve folder contents and the app grid layout.
        folder-children = lib.mkDefault (lib.hm.gvariant.mkEmptyArray lib.hm.gvariant.type.string);
      };
      "org/gnome/shell" = {
        favorite-apps = lib.mkDefault (
          [ "org.gnome.TextEditor.desktop" ]
          ++ lib.concatMap (app: lib.optional (app != null && app.desktopId != null) app.desktopId) [
            config.desktop.applications.fileManager
            config.desktop.applications.terminal
          ]
        );
      };
      "org/gnome/shell/extensions/dash-to-dock" = lib.mapAttrs (_: lib.mkDefault) {
        dock-position = "BOTTOM";
        dock-fixed = true;
        autohide = false;
        intellihide = false;
        custom-theme-shrink = true;
        disable-overview-on-startup = true;
        show-show-apps-button = true;
        show-mounts = false;
        show-apps-at-top = true;
        show-apps-always-in-the-edge = true;
        extend-height = true;
      };
    }
  ];

  programs.gnome-shell.enable = lib.mkDefault true;

  xdg.userDirs = {
    enable = lib.mkDefault true;
    createDirectories = lib.mkDefault true;
  };
}
