{ pkgs }:
let
  recipes = import ./profile-recipes.nix { inherit pkgs; };
in
builtins.mapAttrs (_: entries: pkgs.lib.genAttrs (builtins.attrNames entries) (_: { })) recipes
