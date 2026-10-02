{
  config,
  lib,
  software,
  ...
}:
{
  desktop.applications = {
    terminal = lib.mkIf (config.features.ghostty.enable && config.programs.ghostty.enable) (
      lib.mkDefault {
        command = [ (software.ghostty.command "ghostty") ];
        desktopId = "com.mitchellh.ghostty.desktop";
      }
    );
    fileManager = lib.mkIf (config.features.desktop.fileManager.enable) (
      lib.mkDefault {
        command = [ (software.nautilus.command "nautilus") ];
        desktopId = "org.gnome.Nautilus.desktop";
        appId = "^org\\.gnome\\.Nautilus$";
      }
    );
  };
}
