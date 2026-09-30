{ lib, ... }: {
  options.services.avahi = {
    enable = lib.mkEnableOption "Avahi service discovery";
    nssmdns4 = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };
}
