{ inputs }:

{
  nixos = import ./nixos.nix { inherit inputs; };
  darwin = import ./darwin.nix { inherit inputs; };
  homeManager = import ./home-manager.nix { inherit inputs; };
}
