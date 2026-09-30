{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [ ./base.nix ];

  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;
}
