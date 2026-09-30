{
  lib,
  name,
  platform,
  defaults,
  overrides,
  preferences ? { },
  modules ? [ ],
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
      modules
      ;
  };
  desktopSession = import ./desktop-session.nix {
    inherit (resolved) selected enabled;
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
  platforms = import ../hosts/platforms.nix;

in
assert lib.assertMsg (resolved.errors == [ ]) (lib.concatStringsSep "\n" resolved.errors);
{
  inherit (resolved) enabled selected;
  homeModules = lib.concatMap (entry: entry.homeModules or [ ]) entries ++ [
    {
      features = resolved.config;
      _module.args = { inherit desktopSession; };
      software.requirements = lib.genAttrs (lib.unique (
        lib.concatMap (entry: entry.software or [ ]) entries
      )) (_: { });
    }

    (contractCheck "home")
    dependencyChecks.homeModule
    (import ../../modules/integrations/user-resources.nix {
      inherit (resolved) enabled;
    })
  ];
  systemModules =
    lib.optionals platforms.definitions.${platform}.managesSystem (
      lib.concatMap (entry: entry.systemModules or [ ]) entries
    )
    ++ [
      dependencyChecks.systemModule
      { _module.args = { inherit desktopSession; }; }
      (contractCheck "system")
    ]
    ++ lib.optional (port ? systemPolicy) (
      import port.systemPolicy {
        inherit desktopSession;
        inherit (resolved) enabled;
      }
    );
}
