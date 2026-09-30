{ config, lib, ... }:
let
  cfg = config.features.desktop.fileManager;
  chooser = {
    sort-directories-first = lib.mkDefault cfg.sortDirectoriesFirst;
    show-hidden = lib.mkDefault cfg.showHiddenFiles;
  };
in
{
  dconf = {
    enable = lib.mkDefault true;
    settings = {
      # Nautilus versions use either GTK3 or GTK4's shared chooser settings.
      # Keep both consistent, including the Open/Save dialogs of GTK apps.
      "org/gtk/settings/file-chooser" = chooser;
      "org/gtk/gtk4/settings/file-chooser" = chooser;
      "org/gnome/nautilus/preferences" = {
        show-create-link = lib.mkDefault cfg.showCreateLink;
        show-delete-permanently = lib.mkDefault cfg.showDeletePermanently;
      };
    };
  };
  xdg.mimeApps = {
    enable = lib.mkDefault true;
    defaultApplications."inode/directory" = lib.mkDefault [ "org.gnome.Nautilus.desktop" ];
  };
}
