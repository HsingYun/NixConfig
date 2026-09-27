{ lib, pkgs, ... }:

{
  programs.nh.enable = lib.mkDefault true;
  home.packages = [
    pkgs.git
    pkgs.nixfmt
  ];
}
