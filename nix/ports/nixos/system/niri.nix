{
  lib,
  pkgs,
  ...
}:

{
  imports = [ ./desktop-nixos.nix ];
  programs.niri.enable = lib.mkDefault true;
  fonts.packages = [ pkgs.nerd-fonts.jetbrains-mono ];
}
