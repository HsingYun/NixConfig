{ lib }:
let
  nixos = import ./nixos.nix { inherit lib; };
in
{
  arch = import ./arch.nix { inherit lib; };
  inherit nixos;
  nixos-wsl = nixos;
  darwin."system.mihomo" = { system, ... }: system.launchd.daemons ? mihomo;
}
