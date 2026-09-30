{ lib, ... }: {
  options.programs.dms-shell = {
    enable = lib.mkEnableOption "DMS";
    systemd.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
  };
  options.services.displayManager.dms-greeter.enable = lib.mkEnableOption "DMS greeter";
}
