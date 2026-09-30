{
  config,
  lib,
  user,
  ...
}:
let
  features = config.home-manager.users.${user.username}.features.desktop;
in
{
  imports = [ ../shared/desktop.nix ];
  services.desktopManager.gnome.enable = lib.mkIf features.gnome.enable (lib.mkDefault true);
  programs.niri.enable = lib.mkIf (features.niri.enable || features.dms.enable) (lib.mkDefault true);
  programs.dms-shell.enable = lib.mkIf features.dms.enable (lib.mkDefault true);
}
