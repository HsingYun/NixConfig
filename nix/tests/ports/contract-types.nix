{ lib, pkgs }:
let
  contracts = import ../../contracts;
  evaluate =
    name: change:
    let
      expected =
        (lib.evalModules {
          specialArgs = { inherit pkgs; };
          modules = [ contracts.${name}.module ];
        }).options;
      # Deliberately omit defaults: checking a dormant port must still work.
      declarations = lib.foldl' lib.recursiveUpdate { } (
        map (
          option: lib.setAttrByPath option.loc (lib.mkOption { type = change option.loc option.type; })
        ) (lib.collect lib.isOption (builtins.removeAttrs expected [ "_module" ]))
      );
      actual = lib.evalModules { modules = [ { options = declarations; } ]; };
      checks = import ../../contracts/check.nix {
        inherit lib pkgs;
        names = [ name ];
        options = actual.options;
      };
    in
    lib.all (check: check.assertion) checks;
  changePrinting =
    replacement: path: type:
    if
      path == [
        "services"
        "printing"
        "enable"
      ]
    then
      replacement
    else
      type;
in
assert lib.all (name: evaluate name (_: type: type)) (builtins.attrNames contracts);
assert !(evaluate "system.printing" (changePrinting lib.types.str));
assert !(evaluate "system.printing" (changePrinting (lib.types.enum [ false ])));
assert !(evaluate "system.printing" (changePrinting (lib.types.enum [ true ])));
assert
  !(evaluate "home.dms" (
    path: type:
    if
      path == [
        "programs"
        "dank-material-shell"
        "package"
      ]
    then
      lib.types.enum [ null ]
    else
      type
  ));
assert
  !(evaluate "system.niri" (
    path: type:
    if
      path == [
        "services"
        "greetd"
        "settings"
      ]
    then
      lib.types.attrsOf lib.types.str
    else
      type
  ));
{
  dormantOptionsChecked = true;
  bothBooleanValuesAccepted = true;
  structuredValuesCheckedByUpstreamModuleSystem = true;
}
