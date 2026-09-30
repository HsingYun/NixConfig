{ lib, ... }:
{
  options = {
    services.pcscd.enable = lib.mkEnableOption "PC/SC smart-card service";
    security.polkit = {
      enable = lib.mkEnableOption "Polkit";
      extraConfig = lib.mkOption {
        type = lib.types.lines;
        default = "";
      };
    };
  };
}
