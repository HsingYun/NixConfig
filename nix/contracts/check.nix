{
  lib,
  pkgs,
  names,
  options,
}:
let
  contracts = import ./.;
  check =
    name:
    assert lib.assertMsg (contracts ? ${name}) "Unknown port contract '${name}'.";
    let
      contract = contracts.${name};
      declarations =
        (lib.evalModules {
          specialArgs = { inherit pkgs; };
          modules = [ contract.module ];
        }).options;
      expected = lib.collect lib.isOption (builtins.removeAttrs declarations [ "_module" ]);
    in
    map (
      option:
      let
        actual = lib.attrByPath option.loc null options;
      in
      {
        # Dormant options may have no value. Validate actual configured values
        # without exercising synthetic configurations during normal evaluation.
        assertion =
          actual != null && lib.isOption actual && (!actual.isDefined || option.type.check actual.value);
        message = "Port contract '${name}' is missing or incompatible at '${lib.concatStringsSep "." option.loc}'.";
      }
    ) expected;
in
lib.concatMap check names
