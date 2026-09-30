{
  config,
  lib,
  ...
}:

{
  assertions = [
    {
      assertion = !config.features.smartcard.allowBackgroundAccess;
      message = "smartcard.allowBackgroundAccess configures Linux Polkit; macOS manages smart-card access itself.";
    }
  ];
  # macOS owns the smart-card service; GnuPG already knows its PC/SC framework.
  programs.gpg.scdaemonSettings.disable-ccid = lib.mkIf (config.programs.gpg.enable) (
    lib.mkDefault true
  );
}
