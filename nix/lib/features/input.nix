{ lib, catalog }:
# Generate real module options rather than maintaining a second option engine.
{
  name,
  platform,
  defaults,
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
      {
        _file = "Host ${name}: shared feature defaults";
        config.features = lib.mkDefault defaults;
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
