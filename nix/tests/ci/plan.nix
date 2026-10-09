{ lib }:
{ checks, groups }:
let
  expected = lib.concatLists (
    lib.mapAttrsToList (
      system: values: map (name: "${system}.${name}") (builtins.attrNames values)
    ) checks
  );
  assigned = lib.concatLists (
    lib.mapAttrsToList (_: group: map (name: "${group.system}.${name}") group.checks) groups
  );
  missing = lib.subtractLists assigned expected;
  unknown = lib.subtractLists expected assigned;
  duplicates = lib.filter (name: lib.count (entry: entry == name) assigned > 1) (lib.unique assigned);
in
# Inspect names only: planning must not evaluate any test or host derivation.
assert lib.assertMsg (
  missing == [ ]
) "CI checks without a group: ${lib.concatStringsSep ", " missing}";
assert lib.assertMsg (
  unknown == [ ]
) "CI groups reference unknown checks: ${lib.concatStringsSep ", " unknown}";
assert lib.assertMsg (
  duplicates == [ ]
) "CI checks assigned more than once: ${lib.concatStringsSep ", " duplicates}";
{
  include = lib.mapAttrsToList (name: group: {
    inherit name;
    inherit (group) system runner;
    installables = map (check: ".#checks.${group.system}.${check}") group.checks;
  }) groups;
}
