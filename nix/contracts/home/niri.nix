{ lib, ... }:
{
  options.wayland.windowManager.niri = {
    enable = lib.mkEnableOption "Niri user configuration";
    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
    };
    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
    };
    systemd.enable = lib.mkEnableOption "Niri user service";
  };
}
