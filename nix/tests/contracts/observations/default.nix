{ lib }:
let
  nixos = import ./nixos.nix { inherit lib; };
in
{
  arch = import ./arch.nix { inherit lib; };
  inherit nixos;
  nixos-wsl = nixos;
  # Darwin currently declares only home contracts, whose effects are shared.
  darwin = { };
}
