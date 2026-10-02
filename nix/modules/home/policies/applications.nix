{
  config,
  lib,
  software,
  ...
}:
let
  defaults = {
    terminal = {
      enable = config.features.ghostty.enable && config.programs.ghostty.enable;
      value = {
        command = [ (software.ghostty.command "ghostty") ];
        desktopId = "com.mitchellh.ghostty.desktop";
      };
    };
    fileManager = {
      enable = config.features.desktop.fileManager.enable;
      value = {
        command = [ (software.nautilus.command "nautilus") ];
        desktopId = "org.gnome.Nautilus.desktop";
        appId = "^org\\.gnome\\.Nautilus$";
      };
    };
  };
in
{
  # Extend the shared schema with policy defaults inside each submodule. An
  # outer null still disables the role; a field override keeps its siblings.
  options.desktop.applications = lib.mapAttrs (
    _: default:
    lib.mkOption {
      type = lib.types.nullOr (
        lib.types.submodule {
          config = lib.mkIf default.enable (lib.mapAttrs (_: lib.mkDefault) default.value);
        }
      );
    }
  ) defaults;
  config.desktop.applications = lib.mapAttrs (
    _: default: lib.mkIf default.enable (lib.mkDefault { })
  ) defaults;
}
