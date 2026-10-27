{ lib, ... }: {
  imports = [ ./niri.nix ];
  programs.dux-shell.enable = lib.mkDefault true;
}
