{
  config,
  lib,
  ...
}:
let
  niriEnabled = config.features.desktop.niri.enable && config.wayland.windowManager.niri.enable;
in
{
  home.stateVersion = "26.05";
  # The native package is declared in this host's packageManager.extraPkg.
  wayland.windowManager.niri.settings.binds."Mod+B" = lib.mkIf niriEnabled {
    spawn = [ "/usr/bin/microsoft-edge-stable" ];
  };
}
