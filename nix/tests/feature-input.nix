{ lib }:
let
  catalog = (import ../lib/features/catalog.nix).features;
in
# Scenario matrices use stable feature IDs internally; exercise the public
# hierarchical input at the resolver/host boundary.
values:
if !builtins.isAttrs values then
  values
else
  lib.foldl' lib.recursiveUpdate { } (
    lib.mapAttrsToList (
      name: value: lib.setAttrByPath ((catalog.${name}.path or [ name ]) ++ [ "enable" ]) value
    ) values
  )
