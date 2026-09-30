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

    ({ config, ... }: {
      nixpkgs.hostPlatform = system;
      networking.hostName = hostname;
      users.users.${user.username}.home = homeDirectory;

      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        extraSpecialArgs = {
          inherit inputs user;
        };

        users.${user.username} = {
          imports = [ homeModule ];
          software.externalPlan = config.software.plan;
          software.hostContext = { inherit (config.software) platform packageManager nativePrefix; };
        };
      };
    })
  ]
  ++ systemModules;
}
