{ config, software, ... }:
{
  imports = [
    (import ../../../modules/home/integrations/niri-dms.nix {
      enabled = config.programs.dank-material-shell.enable or false;
      dms = software.dms.command "dms";
    })
  ];
}
