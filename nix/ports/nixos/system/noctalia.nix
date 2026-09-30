{ config, lib, ... }: {
  imports = [
    ../../../modules/system/features/noctalia.nix
    ./desktop.nix
  ];
  systemd.user.services.noctalia =
    lib.mkIf (config.programs.noctalia.enable && config.programs.noctalia.systemd.enable)
      {
        unitConfig.ConditionEnvironment = lib.mkIf (
          config.programs.noctalia.systemd.target == "niri.service"
        ) "XDG_CURRENT_DESKTOP=niri";
      };
}
