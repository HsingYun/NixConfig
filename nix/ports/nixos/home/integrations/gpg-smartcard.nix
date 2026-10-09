{
  config,
  lib,
  osConfig,
  ...
}:

{
  # Coordinate PC/SC with the managed user's GPG configuration.
  programs.gpg.scdaemonSettings.disable-ccid = lib.mkIf (
    osConfig.services.pcscd.enable && config.programs.gpg.enable
  ) (lib.mkDefault true);
}
