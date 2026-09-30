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
  desktopDefaults = import ./desktop-defaults.nix {
    inherit (resolved) selected;
    sessions = catalog.choices.desktop.sessions;
  };
  active = lib.filterAttrs (key: _: resolved.enabled.${key}) catalog.features;
  integrations = lib.filterAttrs (
    _: entry:
    builtins.elem platform entry.platforms && lib.any (key: resolved.enabled.${key}) entry.owners
  ) catalog.integrations;
  port = platforms.definitions.${platform};
  contracts = import ../../contracts;
  contractCheck = scope: { options, pkgs, ... }: {
    assertions = import ../../contracts/check.nix {
      inherit lib pkgs options;
      names = lib.filter (name: contracts.${name}.scope == scope) port.contracts;
    };
  };
  attach =
    section: entries:
    lib.mapAttrsToList (
      key: entry:
      let
        implementation = port.${section}.${key} or { };
      in
      entry
      // {
        homeModules = (entry.homeModules or [ ]) ++ (implementation.homeModules or [ ]);
        systemModules =
          lib.optionals (builtins.elem platform (entry.systemPlatforms or entry.platforms)) (
            entry.systemModules or [ ]
          )
          ++ (implementation.systemModules or [ ]);
      }
    ) entries;
  entries = attach "features" active ++ attach "integrations" integrations;
  dependencyChecks = import ./assertions.nix {
    inherit lib catalog platform;
    inherit (resolved) enabled;
  };
  platforms = import ../platforms/default.nix;

in
assert lib.assertMsg (resolved.errors == [ ]) (lib.concatStringsSep "\n" resolved.errors);
{
  inherit (resolved) enabled selected;
  homeModules = lib.concatMap (entry: entry.homeModules or [ ]) entries ++ [
    {
      features = resolved.config;
      software.requirements = lib.genAttrs (lib.unique (
        lib.concatMap (entry: entry.software or [ ]) entries
      )) (_: { });
    }

    (contractCheck "home")
    (lib.optionalAttrs
      (lib.any (
        name: builtins.elem "system.${name}" port.contracts && builtins.elem "home.${name}" port.contracts
      ) (builtins.attrNames (import ./desktop-shells.nix)))
      {
        imports = [ (import ../../modules/home/shared/desktop-shells.nix { inherit (port) contracts; }) ];
      }
    )
    dependencyChecks.homeModule
    (import ../../modules/home/integrations/user-resources.nix {
      inherit (resolved) enabled;
    })
  ];
  systemModules =
    lib.optionals platforms.definitions.${platform}.managesSystem (
      lib.concatMap (entry: entry.systemModules or [ ]) entries
    )
    ++ [
      dependencyChecks.systemModule
      (contractCheck "system")
    ]
    ++ lib.optional (builtins.elem "system.session" port.contracts) (
      import ../../modules/system/shared/desktop-policy.nix {
        inherit desktopDefaults;
        inherit (port) contracts;
      }
    )
    ++ lib.optional (port ? systemPolicy) (import port.systemPolicy { inherit (resolved) enabled; });
}
