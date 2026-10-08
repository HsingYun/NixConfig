{ lib, catalog }:
# Generate real module options rather than maintaining a second option engine.
{
  name,
  platform,
  defaults,
  profiles,
  overrides,
}:
let
  pathFor = key: catalog.features.${key}.path or [ key ];
  supported = entry: builtins.elem platform entry.platforms;
  evaluation = lib.evalModules {
    modules = [
      ({ config, ... }: {
        options.features = lib.foldl' lib.recursiveUpdate { } (
          lib.mapAttrsToList (
            key: entry:
            lib.setAttrByPath (pathFor key) (
              {
                enable = lib.mkOption {
                  type = lib.types.bool;
                  default =
                    supported entry
                    && (
                      ((entry.default or false) && builtins.elem platform (entry.defaultPlatforms or entry.platforms))
                      || lib.any (other: lib.getAttrFromPath (pathFor other ++ [ "enable" ]) config.features) (
                        entry.defaultFrom or [ ]
                      )
                    );
                  description = "Enable the ${key} feature.";
                };
              }
              // lib.mapAttrs (_: spec: lib.mkOption spec) (entry.options or { })
            )
          ) catalog.features
        );
      })
      ({ config, ... }: {
        # A selected provider takes precedence over profile defaults (950),
        # but platform restrictions (900) and explicit host definitions win.
        config.features = lib.mkMerge (
          lib.concatMap (
            rule:
            lib.mapAttrsToList (
              provider: features:
              lib.mkIf
                (
                  lib.getAttrFromPath (pathFor rule.source.feature ++ [ "enable" ]) config.features
                  &&
                    lib.getAttrFromPath (pathFor rule.source.feature ++ [ rule.source.option ]) config.features
                    == provider
                )
                (
                  lib.mkMerge (
                    map (feature: lib.setAttrByPath (pathFor feature ++ [ "enable" ]) (lib.mkOverride 925 true)) (
                      lib.toList features
                    )
                  )
                )
            ) rule.providers
          ) (builtins.attrValues (lib.filterAttrs (_: rule: rule ? source) catalog.choices))
        );
      })
      {
        _file = "Host ${name}: shared feature defaults";
        config.features = lib.mkDefault defaults;
      }
      {
        _file = "Host ${name}: profiles";
        config.features = lib.mkOverride 950 (lib.mkMerge (lib.toList profiles));
      }
      {
        _file = "Host ${name}: features";
        config.features = overrides;
      }
      # Unsupported shared profile entries are disabled at a stronger default
      # priority. An explicit host enable remains visible to platform validation.
      {
        config.features = lib.mkMerge (
          lib.mapAttrsToList (
            key: entry:
            lib.optionalAttrs (!(supported entry)) (
              lib.setAttrByPath (pathFor key ++ [ "enable" ]) (lib.mkOverride 900 false)
            )
          ) catalog.features
        );
      }
    ];
  };
in
evaluation.config.features
