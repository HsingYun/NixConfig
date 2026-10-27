{
  config,
  osConfig,
  software,
  ...
}:
{
  imports = [
    (import ../../../../modules/home/integrations/niri-dms.nix {
      enabled =
        (osConfig.programs.dux-shell.enable && osConfig.programs.dux-shell.systemd.enable)
        || (
          config.programs.dank-material-shell.enable && config.programs.dank-material-shell.systemd.enable
        );
      dms = software.dms.command "dms";
    })
  ];
}
