{
  config,
  osConfig,
  software,
  ...
}:
{
  imports = [
    (import ../../../modules/home/integrations/niri-dms.nix {
      enabled =
        (osConfig.programs.dms-shell.enable && osConfig.programs.dms-shell.systemd.enable)
        || (
          config.programs.dank-material-shell.enable && config.programs.dank-material-shell.systemd.enable
        );
      dms = software.dms.command "dms";
    })
  ];
}
