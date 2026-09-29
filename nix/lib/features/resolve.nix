{
  lib,
  catalog ? import ./catalog.nix,
}:

let
  catalogErrors = import ./validate.nix { inherit lib; } catalog;
in
assert lib.assertMsg (catalogErrors == [ ]) (lib.concatStringsSep "\n" catalogErrors);

{
  name,
  platform,
  defaults ? { },
  overrides ? { },
  preferences ? { },
}:

let
  definitions = catalog.features;
  names = builtins.attrNames definitions;
  prefix = "Host ${name}: ";
  input = import ./input.nix { inherit lib catalog; };
  shared = input.normalize "shared features" defaults;
  local = input.normalize "features" overrides;
  explicit = lib.recursiveUpdate shared.values local.values;
  pathFor = key: definitions.${key}.path or [ key ];
  enableKey = key: lib.concatStringsSep "." (pathFor key ++ [ "enable" ]);
  supported = key: builtins.elem platform definitions.${key}.platforms;
  enabled = lib.genAttrs names (
    key:
    supported key
    && (explicit.${enableKey key} or (
      (
        (definitions.${key}.default or false)
        && builtins.elem platform (definitions.${key}.defaultPlatforms or definitions.${key}.platforms)
      )
      || lib.any (other: enabled.${other}) (definitions.${key}.defaultFrom or [ ])
    )
    )
  );
  featureErrors = lib.concatMap (
    key:
    lib.optional (
      (local.values.${enableKey key} or false) && !supported key
    ) "features.${lib.concatStringsSep "." (pathFor key)} is not supported on platform '${platform}'."
    ++ lib.concatMap (
      other:
      lib.optional (enabled.${key} && enabled.${other})
        "features.${lib.concatStringsSep "." (pathFor key)} conflicts with features.${lib.concatStringsSep "." (pathFor other)}."
    ) (definitions.${key}.conflicts or [ ])
  ) names;
  preferenceValues = if builtins.isAttrs preferences then preferences else { };
  preferenceErrors =
    if !builtins.isAttrs preferences then
      [ "preferences must be an attribute set." ]
    else
      map (key: "unknown preferences.${key}.") (
        lib.subtractLists (builtins.attrNames catalog.choices) (builtins.attrNames preferences)
      );
  choices = lib.mapAttrs (
    key: rule:
    let
      applicable = !(rule ? platforms) || builtins.elem platform rule.platforms;
      candidates = builtins.attrNames (
        lib.filterAttrs (
          _: features: lib.any (feature: enabled.${feature}) (lib.toList features)
        ) rule.providers
      );
      supplied = preferenceValues.${key} or null;
      valid =
        supplied == null
        || (
          builtins.isString supplied && builtins.elem supplied (candidates ++ (rule.alternatives or [ ]))
        );
    in
    {
      value =
        if !applicable then
          rule.empty
        else if supplied != null then
          supplied
        else if builtins.length candidates == 1 then
          builtins.head candidates
        else
          rule.empty;
      errors =
        if !applicable then
          lib.optional (
            supplied != null
          ) "preferences.${key} is managed by the host OS on platform '${platform}'."
        else
          lib.optional (!valid)
            "preferences.${key} must select an available value: ${
              lib.concatStringsSep ", " (candidates ++ (rule.alternatives or [ ]))
            }."
          ++
            lib.optional (supplied == null && builtins.length candidates > 1)
              "multiple ${key} providers are enabled (${lib.concatStringsSep ", " candidates}); set preferences.${key} explicitly.";
    }
  ) catalog.choices;
in
{
  inherit enabled;
  config = lib.foldl' lib.recursiveUpdate { } (
    lib.mapAttrsToList (
      key: entry:
      lib.setAttrByPath (pathFor key) (
        {
          enable = enabled.${key};
        }
        // lib.mapAttrs (
          option: spec: explicit.${lib.concatStringsSep "." (pathFor key ++ [ option ])} or spec.default
        ) (entry.options or { })
      )
    ) definitions
  );
  selected = lib.mapAttrs (_: choice: choice.value) choices;
  errors = map (error: prefix + error) (
    shared.errors
    ++ local.errors
    ++ featureErrors
    ++ preferenceErrors
    ++ lib.concatMap (choice: choice.errors) (builtins.attrValues choices)
  );
}
