{ lib, pkgs, ... }: {
  options.programs.noctalia = {
    enable = lib.mkEnableOption "Noctalia configuration";
    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
    };
    systemd.enable = lib.mkEnableOption "Noctalia user service";
    checkConfig = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    settings = lib.mkOption {
      type = lib.types.oneOf [
        (pkgs.formats.toml { }).type
        lib.types.str
        lib.types.path
      ];
      default = { };
    };
    customPalettes = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.oneOf [
          (pkgs.formats.json { }).type
          lib.types.str
          lib.types.path
        ]
      );
      default = { };
    };
  };
}
