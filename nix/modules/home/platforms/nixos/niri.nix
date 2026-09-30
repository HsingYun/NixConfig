{ lib, osConfig, ... }:
{
  wayland.windowManager.niri.package = lib.mkDefault osConfig.programs.niri.package;
}
