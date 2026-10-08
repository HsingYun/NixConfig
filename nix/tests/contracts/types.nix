{
  lib,
  pkgs,
  names,
  options,
}:
let
  contracts = import ../../contracts;
  probes = import ./type-probes.nix { inherit lib pkgs; };
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
        # Only public options participate; _module belongs to Nix itself.
        # Probe the portable inputs without depending on the host's defaults.
        samples = map (lib.getAttrFromPath option.loc) (
          lib.filter (lib.hasAttrByPath option.loc) (probes.${name} or [ ])
        );
        accepts =
          value:
          let
            evaluated =
              (lib.evalModules {
                modules = [
                  {
                    options.value = lib.mkOption { type = actual.type; };
                    config.value = value;
                  }
                ];
              }).config.value;
            # JSON forces nested option values while treating derivations as
            # store paths, rather than traversing recursive package passthru.
          in
          (builtins.tryEval (builtins.stringLength (builtins.toJSON evaluated))).success;
      in
      {
        # Upstream options may intentionally have no value while disabled (e.g.
        # greetd.settings). Probe their declared type without forcing that value.
        assertion =
          actual != null
          && lib.isOption actual
          && samples != [ ]
          && lib.all accepts samples
          && (!actual.isDefined || option.type.check actual.value);
        message = "Port contract '${name}' is missing or incompatible at '${lib.concatStringsSep "." option.loc}'.";
      }
    ) expected;
in
lib.concatMap check names
