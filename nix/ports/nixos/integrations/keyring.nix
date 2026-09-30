{ enabled }:
{
  config,
  lib,
  user,
  ...
}:
let
  home = config.home-manager.users.${user.username};
in
{
  # Home Manager owns the daemon; NixOS supplies PAM, DBus and portal support.
  services.gnome.gnome-keyring.enable = lib.mkIf (
    enabled.gnome || enabled.niri || enabled.dms || home.features.desktop.keyring.enable
  ) (lib.mkOverride 900 home.features.desktop.keyring.enable);
  security.pam.services = lib.mkIf (
    config.services.greetd.enable && home.features.desktop.keyring.enable
  ) { greetd.enableGnomeKeyring = lib.mkDefault true; };
}
