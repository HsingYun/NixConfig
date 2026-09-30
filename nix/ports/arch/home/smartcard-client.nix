{
  config,
  lib,
  hostSystem,
  ...
}:
{
  programs.gpg.scdaemonSettings.disable-ccid = lib.mkIf (
    hostSystem.services.pcscd.enable && config.programs.gpg.enable
  ) (lib.mkDefault true);
}
