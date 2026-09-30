{ lib, ... }:
{
  options.services = {
    printing.enable = lib.mkEnableOption "CUPS printing";
    avahi = {
      enable = lib.mkEnableOption "Avahi service discovery";
      nssmdns4 = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
    };
    fwupd.enable = lib.mkEnableOption "firmware updates";
  };
}
