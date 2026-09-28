{
  lib,
  pkgs,
  user,
  ...
}:

{
  imports = [ ../shared/user-profile.nix ];

  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";

  users.users.${user.username} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };
}
