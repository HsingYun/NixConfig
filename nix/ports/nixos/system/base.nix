{ lib, user, ... }:

{
  imports = [
    ./software-consumers.nix
    ./user-profile.nix
  ];

  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";

  users.users.${user.username} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };
}
