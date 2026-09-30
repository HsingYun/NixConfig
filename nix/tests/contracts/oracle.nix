# Each observation is independent: disabling must retire every effect, not just
# make a conjunction false after one of several effects has disappeared.
{ lib }:
expected: observations:
assert lib.assertMsg (
  observations != { } && lib.all builtins.isBool (builtins.attrValues observations)
) "Contract behavior observers must return a nonempty set of boolean effects.";
lib.all (effect: effect == expected) (builtins.attrValues observations)
