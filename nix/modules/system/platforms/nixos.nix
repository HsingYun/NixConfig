{ lib, pkgs, ... }:

{
  imports = [ ../shared/nixos.nix ];

  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;
}
