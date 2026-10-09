{
  config,
  lib,
  osConfig,
  ...
}:
let
  system = osConfig.programs.dms-shell;
  home = config.programs.dank-material-shell;
  systemRunning = system.enable && system.systemd.enable;
in
{
  imports = [
    (import ../../../../modules/home/integrations/niri-dms.nix {
      enabled = osConfig.programs.niri.enable && (systemRunning || (home.enable && home.systemd.enable));
      dms = lib.getExe (if systemRunning then system.package else home.package);
    })
  ];
}
