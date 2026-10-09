{
  lib,
  contracts ? import ../../contracts,
}:
{ registry, catalog }:
let
  ports = registry.definitions;
  providers = import ../software/providers.nix {
    inherit lib;
    nativePrefix = "";
  };
  strings = value: builtins.isList value && lib.all (v: builtins.isString v && v != "") value;
  uniqueStrings = value: strings value && lib.unique value == value;
  modules =
    value:
    builtins.isList value
    && lib.all (
      m: builtins.isFunction m || builtins.isAttrs m || (builtins.isPath m && builtins.pathExists m)
    ) value;
  fields =
    path: required: schema: value:
    if !builtins.isAttrs value then
      [ "${path} must be an attribute set." ]
    else
      map (key: "${path}.${key} is required.") (lib.subtractLists (builtins.attrNames value) required)
      ++ lib.concatMap (
        key:
        if !(schema ? ${key}) then
          [ "${path}.${key} is unknown." ]
        else
          lib.optional (!(schema.${key} value.${key})) "${path}.${key} has an invalid value."
      ) (builtins.attrNames value);
  required = [
    "contracts"
    "packageProviders"
    "capabilities"
    "managesSystem"
    "requiresHardwareConfig"
    "family"
    "upstreamNixos"
    "output"
    "builder"
    "packageManager"
    "defaultSystem"
    "systemModules"
    "homeModules"
  ];
  schema = {
    contracts = uniqueStrings;
    packageProviders = uniqueStrings;
    capabilities = uniqueStrings;
    managesSystem = builtins.isBool;
    requiresHardwareConfig = builtins.isBool;
    family =
      v:
      builtins.elem v [
        "linux"
        "darwin"
      ];
    upstreamNixos = builtins.isBool;
    output =
      v:
      builtins.elem v [
        "nixosConfigurations"
        "darwinConfigurations"
        "homeConfigurations"
      ];
    builder =
      v:
      builtins.elem v [
        "nixos"
        "darwin"
        "native"
      ];
    packageManager = v: builtins.isString v && v != "";
    defaultSystem = v: builtins.isString v && v != "";
    systemModules = modules;
    homeModules = modules;
    systemPolicy = v: builtins.isPath v && builtins.pathExists v;
    features = builtins.isAttrs;
    integrations = builtins.isAttrs;
  };
  metadataErrors = lib.concatMap (name: fields "Port ${name}" required schema ports.${name}) (
    builtins.attrNames ports
  );
in
if metadataErrors != [ ] then
  metadataErrors
else
  lib.concatMap (
    platform:
    lib.optional (
      !uniqueStrings ports.${platform}.contracts
    ) "Port ${platform}: contracts must be unique names."
    ++ lib.optional (
      !(builtins.elem ports.${platform}.packageManager ports.${platform}.packageProviders)
    ) "Port ${platform}: default package manager must be a supported provider."
    ++ lib.optional (
      !(builtins.elem "nix" ports.${platform}.packageProviders)
    ) "Port ${platform}: Nix must remain available for package overrides and fallback."
    ++ lib.concatMap (
      provider:
      lib.optional (
        !(providers ? ${provider})
      ) "Port ${platform}: unknown package provider '${provider}'."
    ) ports.${platform}.packageProviders
    ++ lib.concatMap (
      name: lib.optional (!(contracts ? ${name})) "Port ${platform}: unknown contract '${name}'."
    ) ports.${platform}.contracts
    ++
      lib.concatMap
        (
          section:
          let
            definitions = catalog.${section};
            registered = ports.${platform}.${section} or { };
          in
          lib.concatMap (
            name:
            lib.optional (!(definitions ? ${name})) "Port ${platform}: unknown ${section}.${name}."
            ++ fields "ports.${platform}.${section}.${name}" [ ] {
              homeModules = modules;
              systemModules = modules;
            } registered.${name}
          ) (builtins.attrNames registered)
          ++ lib.concatMap (
            name:
            let
              entry = definitions.${name};
            in
            lib.optionals (builtins.elem platform entry.platforms) (
              lib.concatMap (
                scope:
                lib.optional (
                  (registered.${name}.${scope + "Modules"} or [ ]) == [ ]
                ) "Port ${platform}: ${section}.${name} requires a ${scope} implementation."
              ) (entry.portScopes or [ ])
            )
          ) (builtins.attrNames definitions)
          ++ lib.concatMap (
            name:
            let
              entry = definitions.${name};
            in
            lib.concatMap (
              contract:
              if !(contracts ? ${contract}) then
                [ "${section}.${name}: unknown contract '${contract}'." ]
              else
                lib.optional (
                  builtins.elem platform (
                    if contracts.${contract}.scope == "home" then
                      entry.platforms
                    else
                      entry.systemPlatforms or entry.platforms
                  )
                  && !(builtins.elem contract ports.${platform}.contracts)
                ) "Port ${platform}: ${section}.${name} requires contract '${contract}'."
            ) (entry.contracts or [ ])
          ) (builtins.attrNames definitions)
        )
        [
          "features"
          "integrations"
        ]
  ) (builtins.attrNames ports)
