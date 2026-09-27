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
  validate =
    source: values:
    if !builtins.isAttrs values then
      [ "${source} must be an attribute set." ]
    else
      lib.concatMap (
        key:
        if !(builtins.elem key names) then
          [ "unknown ${source}.${key}." ]
        else
          lib.optional (!builtins.isBool values.${key}) "${source}.${key} must be true or false."
      ) (builtins.attrNames values);
  clean =
    values:
    if builtins.isAttrs values then
      lib.filterAttrs (key: value: builtins.elem key names && builtins.isBool value) values
    else
      { };
  shared = clean defaults;
  local = clean overrides;
  explicit = shared // local;
  supported = key: builtins.elem platform definitions.${key}.platforms;
  enabled = lib.genAttrs names (
    key: supported key && (explicit.${key} or (definitions.${key}.default or false))
  );
  featureErrors = lib.concatMap (
    key:
    lib.optional (
      (local.${key} or false) && !supported key
    ) "features.${key} is not supported on platform '${platform}'."
    ++ lib.concatMap (
      other:
      lib.optional (
        enabled.${key} && enabled.${other}
      ) "features.${key} conflicts with features.${other}."
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
      candidates = builtins.attrNames (lib.filterAttrs (_: feature: enabled.${feature}) rule.providers);
      supplied = preferenceValues.${key} or null;
      valid =
        supplied == null
        || (
          builtins.isString supplied && builtins.elem supplied (candidates ++ (rule.alternatives or [ ]))
        );
    in
    {
      value =
        if supplied != null then
          supplied
        else if builtins.length candidates == 1 then
          builtins.head candidates
        else
          rule.empty;
      errors =
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
  selected = lib.mapAttrs (_: choice: choice.value) choices;
  errors = map (error: prefix + error) (
    validate "shared features" defaults
    ++ validate "features" overrides
    ++ featureErrors
    ++ preferenceErrors
    ++ lib.concatMap (choice: choice.errors) (builtins.attrValues choices)
  );
}
