{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./base.nix
    ../../../modules/system/shared/mihomo.nix
  ];

  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;
}
