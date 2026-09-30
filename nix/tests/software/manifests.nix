{ inputs }:
let
  inherit (inputs.nixpkgs) lib;
  inherit (import ../fixtures/mk-host.nix { inherit inputs; }) mkHost;
  allOff = lib.genAttrs (builtins.attrNames
    (import ../../lib/features/catalog.nix { inherit lib; }).features
  ) (_: false);
  build =
    systemConfig:
    (mkHost "BrewManifest" {
      platform = "darwin";
      features = allOff // {
        vim = true;
        vscode = true;
      };
      systemConfig = {
        imports = [ systemConfig ];
        system.stateVersion = 6;
      };
      homeConfig.home.stateVersion = "26.05";
    }).views.system;
  dropped = group: build { homebrew.${group} = lib.mkForce [ ]; };
  extended = build { homebrew.brews = [ "hello" ]; };
  check = import ../../lib/software/check-manifest.nix { inherit lib; };
  valid = assertions: lib.all (a: a.assertion) assertions;
in
assert valid extended.assertions;
assert lib.all
  (
    group:
    lib.any (a: !a.assertion && lib.hasInfix "homebrew.${group} drops" a.message)
      (dropped group).assertions
  )
  [
    "brews"
    "casks"
  ];
assert valid (check {
  provider = "test";
  requested.a = [ "one" ];
  actual.a = [
    "one"
    "extra"
  ];
});
assert
  !(valid (check {
    provider = "test";
    requested.a = [ "one" ];
    actual = { };
  }));
{
  droppedBrewAndCaskRequestsRejected = true;
  unrelatedExplicitPackagesPreserved = true;
  missingManifestGroupRejected = true;
}
