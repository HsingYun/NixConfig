{ config, user, ... }:
{
  system.defaults = config.home-manager.users.${user.username}.features.desktop.macos.settings;
}
