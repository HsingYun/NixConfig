{ lib }:

catalog:

let
  platforms = (import ../hosts/platforms.nix).all;
  strings = value: builtins.isList value && lib.all (v: builtins.isString v && v != "") value;
  uniqueStrings = value: strings value && lib.unique value == value;
  identifier =
    value: builtins.isString value && builtins.match "[A-Za-z][A-Za-z0-9_-]*" value != null;
  featurePath = value: builtins.isList value && value != [ ] && lib.all identifier value;
  featureOptions =
    value:
    builtins.isAttrs value
    && lib.all (
      key:
      let
        option = value.${key};
      in
      identifier key
      && key != "enable"
      &&
        fields "option" [ "default" "check" "description" ] {
          default = _: true;
          check = builtins.isFunction;
          description = builtins.isString;
        } option == [ ]
      && option.check option.default
    ) (builtins.attrNames value);
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
    homeModulesByPlatform =
      value:
      builtins.isAttrs value
      && lib.all (p: builtins.elem p platforms && modules value.${p}) (builtins.attrNames value);
    software = uniqueStrings;
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
            defaultPlatforms = platformList;
            path = featurePath;
            options = featureOptions;
            defaultFrom = uniqueStrings;
            requires = uniqueStrings;
            conflicts = uniqueStrings;
            inherit activation;
            activationByPlatform =
              value:
              builtins.isAttrs value
              && lib.all (p: builtins.elem p platforms && activation value.${p}) (builtins.attrNames value);
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
          platforms = platformList;
          providers =
            v:
            builtins.isAttrs v
            && lib.all (x: (builtins.isString x && x != "") || (uniqueStrings x && x != [ ])) (
              builtins.attrValues v
            );
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
    ++
      lib.concatMap
        (
          field:
          lib.optional (lib.any (p: !(builtins.elem p entry.platforms)) (
            builtins.attrNames (entry.${field} or { })
          )) "${path}.${field} keys must be a subset of platforms."
        )
        [
          "homeModulesByPlatform"
          "activationByPlatform"
        ]
    ++ lib.optional (lib.any (p: !(builtins.elem p entry.platforms)) (
      entry.systemPlatforms or [ ]
    )) "${path}.systemPlatforms must be a subset of platforms.";
  referenceErrors =
    lib.concatLists (
      lib.mapAttrsToList (
        name: entry:
        entryRelations "features.${name}" entry
        ++ lib.optional (lib.any (p: !(builtins.elem p entry.platforms)) (
          entry.defaultPlatforms or [ ]
        )) "features.${name}.defaultPlatforms must be a subset of platforms."
        ++ lib.concatMap (reference "features.${name}.defaultFrom") (entry.defaultFrom or [ ])
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
          lib.mapAttrsToList (
            key: features: lib.concatMap (reference "choices.${name}.providers.${key}") (lib.toList features)
          ) rule.providers
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
      lib.concatMap (visit (trail ++ [ key ])) (
        (catalog.features.${key}.requires or [ ]) ++ (catalog.features.${key}.defaultFrom or [ ])
      );
  inputPaths = lib.concatLists (
    lib.mapAttrsToList (
      name: entry:
      map (key: (entry.path or [ name ]) ++ [ key ]) (
        [ "enable" ] ++ builtins.attrNames (entry.options or { })
      )
    ) catalog.features
  );
  pathErrors =
    lib.optional (lib.unique inputPaths != inputPaths) "feature input paths must be unique."
    ++ lib.concatMap (
      path:
      lib.concatMap (
        other:
        lib.optional (
          builtins.length path < builtins.length other && lib.take (builtins.length path) other == path
        ) "feature input path '${lib.concatStringsSep "." path}' cannot also be a group."
      ) inputPaths
    ) inputPaths;
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
    pathErrors ++ dependencyErrors ++ integrationErrors
)
