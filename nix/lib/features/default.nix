{
  lib,
  name,
  platform,
  defaults,
  overrides,
  preferences ? { },
}:

let
  catalog = import ./catalog.nix { inherit lib; };
  resolved = import ./resolve.nix { inherit lib catalog; } {
    inherit
      name
      platform
      defaults
      overrides
      preferences
      ;
  };
  desktopSession = import ./desktop-session.nix { inherit (resolved) selected enabled; };
  active = lib.filterAttrs (key: _: resolved.enabled.${key}) catalog.features;
  integrations = lib.filterAttrs (
    _: entry:
    builtins.elem platform entry.platforms && lib.any (key: resolved.enabled.${key}) entry.owners
  ) catalog.integrations;
  entries = builtins.attrValues active ++ builtins.attrValues integrations;
  dependencyChecks = import ./assertions.nix {
    inherit lib catalog platform;
    inherit (resolved) enabled;
  };
  platforms = import ../hosts/platforms.nix;
  isNixos = builtins.elem platform platforms.nixos;

in
assert lib.assertMsg (resolved.errors == [ ]) (lib.concatStringsSep "\n" resolved.errors);
{
  inherit (resolved) enabled selected;
  homeModules =
    lib.concatMap (
      entry: (entry.homeModules or [ ]) ++ (entry.homeModulesByPlatform.${platform} or [ ])
    ) entries
    ++ [
      {
        features = resolved.config;
        _module.args = { inherit desktopSession; };
        software.requirements = lib.genAttrs (lib.unique (
          lib.concatMap (entry: entry.software or [ ]) entries
        )) (_: { });
      }

      dependencyChecks.homeModule
      (import ../../modules/integrations/user-resources.nix {
        inherit (resolved) enabled;
      })
    ];
  systemModules =
    lib.optionals platforms.definitions.${platform}.managesSystem (
      lib.concatMap (
        entry:
        lib.optionals (builtins.elem platform (entry.systemPlatforms or entry.platforms)) (
          entry.systemModules or [ ]
        )
      ) entries
    )
    ++ lib.optionals isNixos [
      dependencyChecks.systemModule
      (import ../../modules/integrations/system-resources.nix {
        inherit desktopSession;
        inherit (resolved) enabled;
      })
    ];
}
