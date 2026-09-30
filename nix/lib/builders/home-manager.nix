{ inputs }:

{
  system,
  user,
  homeModule,
}:

let
  inherit (inputs) nixpkgs home-manager;
in
home-manager.lib.homeManagerConfiguration {
  pkgs = nixpkgs.legacyPackages.${system};
  extraSpecialArgs = {
    inherit inputs user;
  };

  modules = [
    ../../modules/software/nixpkgs.nix
    homeModule
  ];
}
