{ inputs }:
let
  inherit (inputs.nixpkgs) lib;
  resolve = import ../../lib/software/resolve.nix {
    inherit lib;
    platformProviders = (import ../../lib/platforms).packageProviders;
  };
  cases = {
    supported = {
      meta = { };
      config = { };
      allowed = true;
    };
    unsupported = {
      meta.platforms = [ "x86_64-linux" ];
      config = { };
      allowed = false;
    };
    permittedPlatform = {
      meta.platforms = [ "x86_64-linux" ];
      config.allowUnsupportedSystem = true;
      allowed = true;
    };
    unfree = {
      meta.license = lib.licenses.unfree;
      config = { };
      allowed = false;
    };
    permittedLicense = {
      meta.license = lib.licenses.unfree;
      config.allowUnfree = true;
      allowed = true;
    };
    broken = {
      meta.broken = true;
      config = { };
      allowed = false;
    };
    permittedBroken = {
      meta.broken = true;
      config.allowBroken = true;
      allowed = true;
    };
  };
  succeeds = value: (builtins.tryEval (builtins.deepSeq value true)).success;
in
lib.mapAttrs (
  name: test:
  let
    pkgs = import inputs.nixpkgs {
      system = "aarch64-darwin";
      inherit (test) config;
      overlays = [
        (_: prev: {
          policyProbe = prev.runCommand "policy-probe" { inherit (test) meta; } "touch $out";
        })
      ];
    };
    recipe = (import ../../lib/software/recipe-constructors.nix).nix;
    make =
      args:
      resolve (
        {
          inherit pkgs;
          platform = "darwin";
          packageManager = "nix";
          catalog.probe.nix = recipe pkgs.hello;
          requirements = { };
        }
        // args
      );
    selected = make {
      requirements.probe = { };
      packageOverrides.probe = pkgs.policyProbe;
    };
    catalogSelected = make {
      catalog.probe.nix = recipe pkgs.policyProbe;
      requirements.probe = { };
    };
    extra = make {
      packageManager = {
        type = "nix";
        extraPkg.nix.packages = [ "policyProbe" ];
      };
    };
  in
  assert lib.assertMsg (
    pkgs.policyProbe.meta.available == test.allowed
  ) "Upstream package policy changed: ${name}";
  assert succeeds pkgs.policyProbe.drvPath == test.allowed;
  assert (recipe pkgs.policyProbe).available == test.allowed;
  assert succeeds selected.resolved.probe.provider == test.allowed;
  assert succeeds catalogSelected.resolved.probe.provider == test.allowed;
  assert
    succeeds (map (package: package.drvPath) extra.installations.nix.homePackages) == test.allowed;
  true
) cases
