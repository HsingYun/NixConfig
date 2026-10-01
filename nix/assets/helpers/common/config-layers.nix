{ lib }:
# Ordering for applications that explicitly support layered configuration.
# These are serialization positions, not Nix option override priorities.
# The adapter supplies positions compatible with its upstream module, and
# defines the ownership unit (key, block, rule, or entire file).
{
  strategy,
  layer,
  order,
}:
let
  roles = {
    last-wins = [
      "defaults"
      "runtime"
      "explicit"
    ];
    first-wins = [
      "explicit"
      "runtime"
      "defaults"
    ];
  };
  positions = lib.listToAttrs (lib.zipListsWith lib.nameValuePair roles.${strategy} order);
in
assert lib.assertMsg (
  roles ? ${strategy}
) "Configuration layers: unsupported merge strategy '${strategy}'.";
assert lib.assertMsg (
  builtins.length order == 3
  && lib.all builtins.isInt order
  && builtins.elemAt order 0 < builtins.elemAt order 1
  && builtins.elemAt order 1 < builtins.elemAt order 2
) "Configuration layers: supply three strictly increasing integer positions.";
assert lib.assertMsg (positions ? ${layer}) "Configuration layers: unknown layer '${layer}'.";
lib.mkOrder positions.${layer}
