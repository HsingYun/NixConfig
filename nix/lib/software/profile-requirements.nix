{ pkgs }:
let
  recipes = import ./profiles.nix { inherit pkgs; };
in
builtins.mapAttrs (_: entries: pkgs.lib.genAttrs (builtins.attrNames entries) (_: { })) recipes
