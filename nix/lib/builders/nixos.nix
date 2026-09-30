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
  inherit (inputs) nixpkgs home-manager;
in
nixpkgs.lib.nixosSystem {
  inherit system;

  specialArgs = {
    inherit inputs user;
  };

  modules = [
    ../../modules/system
    home-manager.nixosModules.home-manager

    ({ config, ... }: {
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
