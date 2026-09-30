{ config, lib, ... }:
{
  software.requirements = lib.genAttrs [
    "niri"
    "xwayland-satellite"
    "xdg-desktop-portal-gnome"
    "xdg-desktop-portal-gtk"
  ] (_: { });
  assertions = [
    {
      assertion = lib.all (name: config.software.resolved.${name}.provider == "pacman") [
        "niri"
        "xwayland-satellite"
        "xdg-desktop-portal-gnome"
        "xdg-desktop-portal-gtk"
      ];
      message = "Arch Niri requires pacman compositor/session/portal packages.";
    }
  ];
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
