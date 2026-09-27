{ inputs }:

{
  hostname,
  system,
  user,
  homeDirectory,
  systemModules,
  homeModule,
}:

let
  inherit (inputs) home-manager nix-darwin;
in
nix-darwin.lib.darwinSystem {
  specialArgs = {
    inherit inputs user;
  };

  modules = [
    ../../modules/system
    home-manager.darwinModules.home-manager

    {
      nixpkgs.hostPlatform = system;
      networking.hostName = hostname;
      users.users.${user.username}.home = homeDirectory;

      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        extraSpecialArgs = {
          inherit inputs user;
        };

        users.${user.username} = homeModule;
      };
    }
  ]
  ++ systemModules;
}
