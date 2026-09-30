{
  config,
  lib,
  osConfig,
  ...
}:
{
  config = lib.mkIf (config.wayland.windowManager.niri.enable && osConfig.programs.niri.enable) {
    # Reuse the system runtime and its units/portals. A standalone HM setup
    # without the system session keeps the upstream Home Manager defaults.
    wayland.windowManager.niri = {
      package = lib.mkDefault osConfig.programs.niri.package;
      systemd.enable = lib.mkDefault false;
      portalPackage = lib.mkDefault null;
    };
  };
}
