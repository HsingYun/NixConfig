{ config, lib, ... }:
{
  xdg.dataFile.applications = lib.mkIf (config.desktop.launcher.hiddenEntries != [ ]) {
    source = "${config.desktop.launcher.entries}/share/applications";
    recursive = true;
  };
}
