{ lib, pkgs, ... }: {
  options.services.displayManager.noctalia-greeter = {
    enable = lib.mkEnableOption "Noctalia Greeter";
    settings = lib.mkOption {
      type = (pkgs.formats.toml { }).type;
      default = { };
    };
    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };
  };
}
