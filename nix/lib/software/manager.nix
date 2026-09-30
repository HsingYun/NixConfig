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
  && lib.subtractLists [ "type" "extraPkg" ] (builtins.attrNames manager) == [ ]
) "Software: packageManager must be a name or { type = name; extraPkg = { ... }; }.";
{
  inherit (manager) type;
  extraPkg = manager.extraPkg or { };
}
