{ lib }:
value:
let
  manager = if builtins.isString value then { type = value; } else value;
in
assert lib.assertMsg (
  builtins.isAttrs manager
  && manager ? type
  && builtins.isString manager.type
  && manager.type != ""
  && lib.subtractLists [ "type" "externalPkg" ] (builtins.attrNames manager) == [ ]
) "Software: packageManager must be a name or { type = name; externalPkg = { ... }; }.";
{
  inherit (manager) type;
  externalPkg = manager.externalPkg or { };
}
