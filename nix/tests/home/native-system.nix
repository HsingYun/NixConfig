{ inputs, pkgs }:
let
  lib = pkgs.lib.extend (_: _: { inherit (inputs.home-manager.lib) hm; });
  native = {
    profileDirectory = "/nix/var/nix/profiles/nixconfig-system-test";
    # No Arch module or command participates in this synthetic native port.
    preflight.validate = lib.hm.dag.entryAnywhere "true";
    activation.configure = lib.hm.dag.entryBefore [ "linkGeneration" ] "run true";
    plan = pkgs.writeText "portable-plan.json" (
      builtins.toJSON {
        version = 1;
        owner = "test";
        host = "UbuntuPrototype";
        stages = native.activation;
        resources.packages = {
          desired = {
            apt = [ ];
          };
          check = null;
        };
      }
    );
  };
  cfg =
    (inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      extraSpecialArgs.osConfig = { inherit native; };
      modules = [
        ../../modules/home/native
        {
          home = {
            username = "test";
            homeDirectory = "/home/test";
            stateVersion = "26.05";
          };
        }
      ];
    }).config;
  sorted = lib.hm.dag.topoSort cfg.home.activation;
  names = map (stage: stage.name) sorted.result;
  index = name: lib.lists.findFirstIndex (value: value == name) (-1) names;
in
assert index "validate" < index "writeBoundary";
assert index "writeBoundary" < index "nativeSystemBegin";
assert index "nativeSystemBegin" < index "configure";
assert index "configure" < index "linkGeneration";
assert lib.last names == "nativeSystemComplete";
assert builtins.elem "${native.profileDirectory}/bin" cfg.home.sessionPath;
assert builtins.isString cfg.home.activationPackage.drvPath;
pkgs.writeText "native-system-integration.json" (
  builtins.toJSON {
    distributionIndependent = true;
    inherit names;
  }
)
