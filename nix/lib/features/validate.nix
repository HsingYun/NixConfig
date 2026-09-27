{ lib }:

catalog:

let
  platforms = [
    "linux"
    "nixos"
    "nixos-wsl"
    "darwin"
  ];
  strings = value: builtins.isList value && lib.all (v: builtins.isString v && v != "") value;
  uniqueStrings = value: strings value && lib.unique value == value;
  platformList =
    value: uniqueStrings value && value != [ ] && lib.all (p: builtins.elem p platforms) value;
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
  activation =
    value:
    fields "activation" [ "scope" "option" ] {
      scope =
        v:
        builtins.elem v [
          "home"
          "system"
        ];
      option = v: strings v && v != [ ];
    } value == [ ];
  common = {
    platforms = platformList;
    systemPlatforms = platformList;
    homeModules = modules;
    systemModules = modules;
  };
  rootErrors = fields "catalog" [ "features" "choices" "integrations" ] {
    features = builtins.isAttrs;
    choices = builtins.isAttrs;
    integrations = builtins.isAttrs;
  } catalog;
  entryErrors =
    lib.concatLists (
      lib.mapAttrsToList (
        name:
        fields "features.${name}" [ "platforms" ] (
          common
          // {
            default = builtins.isBool;
            requires = uniqueStrings;
            conflicts = uniqueStrings;
            inherit activation;
          }
        )
      ) catalog.features
    )
    ++ lib.concatLists (
      lib.mapAttrsToList (
        name:
        fields "integrations.${name}" [ "platforms" "owners" ] (
          common
          // {
            owners = v: uniqueStrings v && v != [ ];
          }
        )
      ) catalog.integrations
    )
    ++ lib.concatLists (
      lib.mapAttrsToList (
        name:
        fields "choices.${name}" [ "providers" "empty" ] {
          providers =
            v: builtins.isAttrs v && lib.all (x: builtins.isString x && x != "") (builtins.attrValues v);
          empty = v: v == null || builtins.isString v;
          alternatives = uniqueStrings;
        }
      ) catalog.choices
    );
  names = builtins.attrNames catalog.features;
  reference =
    path: name:
    lib.optional (!(builtins.elem name names)) "${path} references unknown feature '${name}'.";
  entryRelations =
    path: entry:
    lib.concatMap (reference "${path}.requires") (entry.requires or [ ])
    ++ lib.optional (lib.any (p: !(builtins.elem p entry.platforms)) (
      entry.systemPlatforms or [ ]
    )) "${path}.systemPlatforms must be a subset of platforms.";
  referenceErrors =
    lib.concatLists (
      lib.mapAttrsToList (
        name: entry:
        entryRelations "features.${name}" entry
        ++ lib.concatMap (reference "features.${name}.conflicts") (entry.conflicts or [ ])
        ++ lib.optional (builtins.elem name (
          entry.conflicts or [ ]
        )) "features.${name} cannot conflict with itself."
      ) catalog.features
    )
    ++ lib.concatLists (
      lib.mapAttrsToList (
        name: entry:
        entryRelations "integrations.${name}" entry
        ++ lib.concatMap (reference "integrations.${name}.owners") entry.owners
      ) catalog.integrations
    )
    ++ lib.concatLists (
      lib.mapAttrsToList (
        name: rule:
        lib.concatLists (
          lib.mapAttrsToList (key: reference "choices.${name}.providers.${key}") rule.providers
        )
        ++ lib.optional (
          rule.empty != null && !(builtins.elem rule.empty (rule.alternatives or [ ]))
        ) "choices.${name}.empty must be null or an alternative."
        ++ lib.optional (
          lib.intersectLists (builtins.attrNames rule.providers) (rule.alternatives or [ ]) != [ ]
        ) "choices.${name}.alternatives must not overlap providers."
      ) catalog.choices
    );
  visit =
    trail: key:
    if builtins.elem key trail then
      [ "dependency cycle: ${lib.concatStringsSep " -> " (trail ++ [ key ])}." ]
    else
      lib.concatMap (visit (trail ++ [ key ])) (catalog.features.${key}.requires or [ ]);
  dependencyErrors = lib.concatMap (
    name:
    let
      entry = catalog.features.${name};
    in
    lib.concatMap (
      dependency:
      lib.concatMap
        (
          key:
          lib.optional (
            !(catalog.features.${key} ? activation)
          ) "features.${key}.activation is required by dependency ${name} -> ${dependency}."
        )
        [
          name
          dependency
        ]
      ++ lib.optional (lib.any (p: !(builtins.elem p catalog.features.${dependency}.platforms))
        entry.platforms
      ) "features.${name}.requires.${dependency} is unavailable on some source platforms."
    ) (entry.requires or [ ])
    ++ visit [ ] name
  ) names;
  integrationErrors = lib.concatLists (
    lib.mapAttrsToList (
      name: entry:
      lib.concatMap (
        owner:
        lib.optional (lib.any (p: !(builtins.elem p catalog.features.${owner}.platforms))
          entry.platforms
        ) "integrations.${name}.owners.${owner} is unavailable on some integration platforms."
      ) entry.owners
    ) catalog.integrations
  );
in
map (message: "Feature catalog: ${message}") (
  if rootErrors != [ ] then
    rootErrors
  else if entryErrors != [ ] then
    entryErrors
  else if referenceErrors != [ ] then
    referenceErrors
  else
    dependencyErrors ++ integrationErrors
)
