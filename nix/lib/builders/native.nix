{ inputs }:
{
  system,
  user,
  hostname,
  homeDirectory,
  homeModule,
  systemModules,
}:
let
  lib = inputs.nixpkgs.lib.extend (_: _: { inherit (inputs.home-manager.lib) hm; });
  evaluateSystem =
    home: pkgs:
    lib.evalModules {
      specialArgs = {
        inherit
          lib
          inputs
          user
          pkgs
          ;
      };
      modules = [
        ../../modules/system/native.nix
        {
          networking.hostName = hostname;
          home-manager.users.${user.username} = home;
        }
      ]
      ++ systemModules;
    };
  home = inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = inputs.nixpkgs.legacyPackages.${system};
    extraSpecialArgs = { inherit inputs user; };
    modules = [
      ../../modules/software/nixpkgs.nix
      homeModule
      (
        {
          config,
          pkgs,
          lib,
          ...
        }:
        let
          systemEvaluation = evaluateSystem config pkgs;
        in
        {
          options.hostSystem = lib.mkOption {
            type = lib.types.raw;
            internal = true;
            readOnly = true;
          };
          config = {
            hostSystem = systemEvaluation.config;
            _module.args.osConfig = systemEvaluation.config;
            software.externalPlan = systemEvaluation.config.software.plan;
            software.hostContext = {
              inherit (systemEvaluation.config.software) platform packageManager nativePrefix;
            };
            assertions = systemEvaluation.config.assertions;
            home.activation = systemEvaluation.config.native.activation;
          };
        }
      )
    ];
  };
in
home
// {
  systemConfiguration = {
    config = home.config.hostSystem;
  };
}
