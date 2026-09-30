{
  config,
  lib,
  user,
  ...
}:

{
  services.resolved.enable = lib.mkDefault true;

  networking = {
    useNetworkd = lib.mkDefault (!config.networking.networkmanager.enable);
    networkmanager.dns = lib.mkDefault "systemd-resolved";
  };

  users.users.${user.username}.extraGroups = lib.mkIf config.networking.networkmanager.enable [
    "networkmanager"
  ];
}
