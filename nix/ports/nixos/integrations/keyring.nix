{ enabled }:
{
  config,
  lib,
  user,
  ...
}:
let
  home = config.home-manager.users.${user.username};
  homeKeyring = home.services.gnome-keyring.enable;
in
{
  # Home Manager owns the daemon; NixOS supplies PAM, DBus and portal support.
  services.gnome.gnome-keyring.enable = lib.mkIf (
    enabled.gnome || enabled.niri || enabled.dms || homeKeyring
  ) (lib.mkOverride 900 homeKeyring);
  security.pam.services = lib.mkIf (
    config.services.greetd.enable && config.services.gnome.gnome-keyring.enable
  ) { greetd.enableGnomeKeyring = lib.mkDefault true; };
}
