# Applicability is derived from declared capabilities, independently of host enablement.
{ lib, platformRegistry }:
definitions:
let
  features = lib.mapAttrs (
    _: entry:
    let
      supported = lib.filter (
        platform:
        lib.all (
          name:
          let
            scope = (import ../../contracts).${name}.scope;
          in
          (scope == "system" && !(builtins.elem platform (entry.systemPlatforms or entry.platforms)))
          || builtins.elem name platformRegistry.definitions.${platform}.contracts
        ) (entry.contracts or [ ])
      ) entry.platforms;
    in
    entry
    // {
      platforms = supported;
    }
    // lib.optionalAttrs (entry ? systemPlatforms) {
      systemPlatforms = lib.intersectLists supported entry.systemPlatforms;
    }
  ) definitions.features;
in
definitions
// {
  inherit features;
  integrations = lib.mapAttrs (
    _: entry:
    entry
    // {
      platforms = lib.filter (
        platform: lib.all (owner: builtins.elem platform features.${owner}.platforms) entry.owners
      ) entry.platforms;
    }
  ) definitions.integrations;
}
