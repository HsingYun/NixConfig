{
  lib,
  platformRegistry ? import ../platforms,
  catalog ? import ./catalog.nix { inherit lib platformRegistry; },
}:

let
  catalogErrors = import ./validate.nix { inherit lib platformRegistry; } catalog;
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
  featureConfig = import ./input.nix { inherit lib catalog; } {
    inherit
      name
      platform
      defaults
      overrides
      ;
  };
  pathFor = key: definitions.${key}.path or [ key ];
  supported = key: builtins.elem platform definitions.${key}.platforms;
  enabled = lib.genAttrs names (key: lib.getAttrFromPath (pathFor key ++ [ "enable" ]) featureConfig);
  featureErrors = lib.concatMap (
    key:
    lib.optional (
      enabled.${key} && !supported key
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
      candidates = lib.filter (
        provider: lib.any (feature: enabled.${feature}) (lib.toList rule.providers.${provider})
      ) (rule.priority or (builtins.attrNames rule.providers));
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
        else if candidates != [ ] && (rule ? priority || builtins.length candidates == 1) then
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
            lib.optional (!(rule ? priority) && supplied == null && builtins.length candidates > 1)
              "multiple ${key} providers are enabled (${lib.concatStringsSep ", " candidates}); set preferences.${key} explicitly.";
    }
  ) catalog.choices;
in
{
  inherit enabled;
  config = featureConfig;
  selected = lib.mapAttrs (_: choice: choice.value) choices;
  errors = builtins.deepSeq featureConfig (
    map (error: prefix + error) (
      featureErrors
      ++ preferenceErrors
      ++ lib.concatMap (choice: choice.errors) (builtins.attrValues choices)
    )
  );
}
