{
  config,
  lib,
  pkgs,
  ...
}:
let
  pinentryPackages = {
    curses = pkgs.pinentry-curses;
    tty = pkgs.pinentry-tty;
    qt = pkgs.pinentry-qt;
    mac = pkgs.pinentry_mac;
  };
in
{
  imports = [ ../shared/gpg-agent.nix ];
  services.gpg-agent.enableZshIntegration = lib.mkDefault true;
  software.packageOverrides.pinentry = lib.mkIf (config.features.gpg.pinentry != null) (
    lib.mkDefault pinentryPackages.${config.features.gpg.pinentry}
  );
}
