{ config, lib, ... }:
{
  home.activation.validateArchNiri = lib.mkIf config.wayland.windowManager.niri.enable (
    lib.hm.dag.entryBetween [ "linkGeneration" ] [ "installNativePackages" ] ''
      run /usr/bin/niri validate --config ${
        lib.escapeShellArg (toString config.xdg.configFile."niri/config.kdl".source)
      }
    ''
  );
  wayland.windowManager.niri = {
    package = null;
    checkConfig = lib.mkDefault false;
    xwaylandSatellitePackage = null;
  };
}
