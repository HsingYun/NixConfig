{ lib, pkgs, ... }: {
  options.services = {
    displayManager = {
      defaultSession = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      gdm.enable = lib.mkEnableOption "GDM";
      dms-greeter.enable = lib.mkEnableOption "DMS greeter";
    };
    greetd = {
      enable = lib.mkEnableOption "greetd";
      settings = lib.mkOption {
        type = (pkgs.formats.toml { }).type;
        default = { };
      };
    };
  };
}
