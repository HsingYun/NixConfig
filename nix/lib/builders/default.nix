{ inputs }:

{
  nixos = import ./nixos.nix { inherit inputs; };
  darwin = import ./darwin.nix { inherit inputs; };
  native = import ./native.nix { inherit inputs; };
}
