{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [ ./nixos.nix ];

  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;
}
