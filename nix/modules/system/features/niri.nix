{ lib, ... }: {
  imports = [ ../shared/desktop.nix ];
  programs.niri.enable = lib.mkDefault true;
}
