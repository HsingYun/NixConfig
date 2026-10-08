{ config, ... }:

{
  home.stateVersion = "26.05";

  desktop.autostart.entries.terminal.command = config.desktop.applications.terminal.command;
}
