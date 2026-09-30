{
  config,
  lib,
  osConfig,
  ...
}:
{
  programs.gpg.scdaemonSettings.disable-ccid = lib.mkIf (
    osConfig.services.pcscd.enable && config.programs.gpg.enable
  ) (lib.mkDefault true);
}
