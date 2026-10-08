{
  config,
  lib,
  pkgs,
  ...
}:
let
  entries = lib.filterAttrs (_: entry: entry.enable) config.desktop.autostart.entries;
  desktopFile =
    name: entry:
    let
      id = "nixconfig-autostart-${name}";
      # Keep literal argv out of Desktop Entry Exec's separate escaping and
      # field-code grammar. The entry invokes a store script with no arguments.
      launcher = pkgs.writeShellScript id ''
        ${lib.optionalString (
          entry.workingDirectory != null
        ) "cd -- ${lib.escapeShellArg entry.workingDirectory} || exit 1"}
        exec ${pkgs.coreutils}/bin/env -- ${
          lib.escapeShellArgs (lib.mapAttrsToList (key: value: "${key}=${value}") entry.environment)
        } ${lib.escapeShellArgs entry.command}
      '';
      desktop = pkgs.makeDesktopItem {
        name = id;
        desktopName = name;
        exec = toString launcher;
        terminal = false;
      };
    in
    "${desktop}/share/applications/${id}.desktop";
in
{
  xdg.autostart = {
    enable = lib.mkDefault true;
    entries = lib.mapAttrsToList desktopFile entries;
  };
}
