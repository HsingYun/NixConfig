{ lib, pkgs, ... }: {
  options.programs.niri.enable = lib.mkEnableOption "Niri";
  options.services.greetd = {
    enable = lib.mkEnableOption "greetd";
    settings = lib.mkOption {
      type = (pkgs.formats.toml { }).type;
      default = { };
    };
  };
}
