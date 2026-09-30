{ lib, ... }:
{
  options.programs.chromium = {
    enable = lib.mkEnableOption "Chromium browser policies";
    extraOpts = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
    };
  };
}
