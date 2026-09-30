{ lib, ... }: {
  imports = [ ./niri.nix ];
  programs.dms-shell.enable = lib.mkDefault true;
}
