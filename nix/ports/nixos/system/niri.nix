{
  lib,
  pkgs,
  ...
}:

{
  imports = [ ./desktop.nix ];
  programs.niri.enable = lib.mkDefault true;
  fonts.packages = [ pkgs.nerd-fonts.jetbrains-mono ];
}
