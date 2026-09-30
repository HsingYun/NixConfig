{ lib, osConfig, ... }:
{
  imports = [
    (import ../../../modules/home/integrations/niri-dms.nix {
      enabled = osConfig.programs.niri.enable && osConfig.programs.dms-shell.enable;
      dms = lib.getExe osConfig.programs.dms-shell.package;
    })
  ];
}
