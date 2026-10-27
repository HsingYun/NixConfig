{ lib, ... }: {
  options.programs.dux-shell = {
    enable = lib.mkEnableOption "DMS";
    systemd.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
  };
  options.services.displayManager.dux-greeter.enable = lib.mkEnableOption "DMS greeter";
}
