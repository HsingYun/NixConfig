{ config, lib, ... }:
let
  entries = lib.filterAttrs (_: entry: entry.enable) config.features.desktop.autostart.entries;
  commandFor =
    name: entry:
    if entry.command != null then
      entry.command
    else
      let
        app = config.desktop.applications.${entry.application};
      in
      assert lib.assertMsg (app != null)
        "Autostart entry '${name}' selects the unavailable '${entry.application}' application role. Select an application, provide a command or disable this entry.";
      app.command;
in
{
  imports = [ ../integrations/autostart.nix ];
  desktop.autostart.entries = lib.mapAttrs (
    name: entry:
    lib.mapAttrs (_: lib.mkDefault) (
      builtins.removeAttrs entry [
        "application"
        "command"
      ]
      // {
        command = commandFor name entry;
      }
    )
  ) entries;
}
