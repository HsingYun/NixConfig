{ lib, ... }: {
  options = {
    security.rtkit.enable = lib.mkEnableOption "RealtimeKit";
    services.pipewire = {
      enable = lib.mkEnableOption "PipeWire";
      alsa.enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      pulse.enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
    };
  };
}
