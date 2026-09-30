{ lib, pkgs, ... }:
let
  json = pkgs.formats.json { };
  settingsOption =
    description:
    lib.mkOption {
      type = json.type;
      default = { };
      inherit description;
    };
in
{
  options.programs.dank-material-shell = {
    enable = lib.mkEnableOption "DankMaterialShell configuration";
    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
    };
    settings = settingsOption "Declarative DMS settings.";
    session = settingsOption "Declarative DMS session state.";
    clipboardSettings = settingsOption "Declarative DMS clipboard settings.";
    enableCalendarEvents = lib.mkEnableOption "DMS calendar dependencies";
    systemd.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the DMS user service.";
    };
  };
}
