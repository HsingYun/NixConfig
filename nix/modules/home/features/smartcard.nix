{
  config,
  lib,
  pkgs,
  ...
}:

{
  assertions = [
    {
      assertion = !pkgs.stdenv.hostPlatform.isDarwin || !config.features.smartcard.allowBackgroundAccess;
      message = "smartcard.allowBackgroundAccess configures Linux Polkit; macOS manages smart-card access itself.";
    }
  ];
  # macOS owns the smart-card service; GnuPG already knows its PC/SC framework.
  programs.gpg.scdaemonSettings.disable-ccid = lib.mkIf (
    pkgs.stdenv.hostPlatform.isDarwin && config.programs.gpg.enable
  ) (lib.mkDefault true);
}
