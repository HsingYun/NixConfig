{ lib, mkHost }:
let
  toTree = import ./feature-input.nix { inherit lib; };
in
name: args:
mkHost name (
  (builtins.removeAttrs args [ "featureConfig" ])
  // {
    features = lib.recursiveUpdate (toTree (args.features or { })) (args.featureConfig or { });
  }
)
