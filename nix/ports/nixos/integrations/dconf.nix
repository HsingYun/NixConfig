{
  config,
  lib,
  user,
  ...
}:
let
  home = config.home-manager.users.${user.username};
  needsDconf = home.dconf.enable && (home.dconf.settings != { } || home.dconf.databases != { });
in
{
  # Any HM consumer can require dconf, even without a desktop feature.
  programs.dconf.enable = lib.mkIf needsDconf (lib.mkDefault true);
}
