{ lib, ... }: {
  options.services.displayManager.defaultSession = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
  };
}
