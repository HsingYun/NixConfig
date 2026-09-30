{ lib, ... }: {
  options.programs.noctalia = {
    enable = lib.mkEnableOption "Noctalia";
    systemd = {
      enable = lib.mkEnableOption "Noctalia user service";
      target = lib.mkOption {
        type = lib.types.str;
        default = "graphical-session.target";
      };
    };
  };
}
