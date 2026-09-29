{
  config,
  lib,
  pkgs,
  ...
}:

{
  # macOS owns the smart-card service; GnuPG already knows its PC/SC framework.
  programs.gpg.scdaemonSettings.disable-ccid = lib.mkIf (
    pkgs.stdenv.hostPlatform.isDarwin && config.programs.gpg.enable
  ) (lib.mkDefault true);
}
