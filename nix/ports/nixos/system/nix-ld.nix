{ lib, ... }:

{
  programs.nix-ld.enable = lib.mkDefault true;
}
