{
  config,
  lib,
  osConfig,
  ...
}:
{
  config = lib.mkIf config.wayland.windowManager.niri.enable {
    assertions = [
      {
        assertion = osConfig.programs.niri.enable;
        message = "Arch Niri user configuration requires the native system session through programs.niri.enable.";
      }
    ];
    # The host owns the runtime, units and portal integration. Home Manager
    # still owns its upstream Niri option schema and configuration generator.
    wayland.windowManager.niri = {
      package = null;
      systemd.enable = lib.mkDefault false;
      portalPackage = null;
      checkConfig = lib.mkDefault false;
      xwaylandSatellitePackage = null;
    };
  };
}
