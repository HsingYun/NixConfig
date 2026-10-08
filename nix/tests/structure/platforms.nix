{ lib }:
let
  base = import ../../lib/platforms;
  registry = import ../../lib/platforms/registry.nix (
    base.definitions
    // {
      example = base.definitions.arch;
      niriOnly = base.definitions.arch // {
        contracts = lib.subtractLists [
          "home.noctalia"
          "system.noctalia"
          "system.noctalia-greeter"
        ] base.definitions.arch.contracts;
        features = builtins.removeAttrs base.definitions.arch.features [ "noctalia" ];
      };
      gnomeOnly = base.definitions.arch // {
        contracts = lib.subtractLists [
          "home.niri"
          "home.dms"
          "home.noctalia"
          "system.niri"
          "system.dms"
          "system.noctalia"
          "system.noctalia-greeter"
        ] base.definitions.arch.contracts;
        features = builtins.removeAttrs base.definitions.arch.features [
          "niri"
          "dms"
          "noctalia"
        ];
        integrations = builtins.removeAttrs base.definitions.arch.integrations [ "niri-dms" ];
      };
    }
  );
  catalog = import ../../lib/features/catalog.nix {
    inherit lib;
    platformRegistry = registry;
  };
  validate = import ../../lib/platforms/validate.nix { inherit lib; };
  resolve = import ../../lib/features/resolve.nix {
    inherit lib catalog;
    platformRegistry = registry;
  };
  selected = resolve {
    name = "FutureDesktop";
    platform = "example";
    overrides.desktop.niri.enable = true;
  };
  partial = resolve {
    name = "PartialDesktop";
    platform = "gnomeOnly";
    overrides.desktop.gnome.enable = true;
  };
  partialShell =
    shell:
    resolve {
      name = "PartialShell";
      platform = "niriOnly";
      overrides.desktop.niri = {
        enable = true;
        inherit shell;
      };
    };
  unavailable = resolve {
    name = "UnavailableDesktop";
    platform = "gnomeOnly";
    overrides.desktop.niri.enable = true;
  };
  # Reuse the common system preset with only the declared GNOME capability.
  # There are intentionally no Niri or DMS options in this module evaluation.
  partialSystem = lib.evalModules {
    specialArgs.user.username = "test";
    modules = [
      ../../modules/system/features/gnome.nix
      ../../modules/shared/features.nix
      (import ../../modules/system/shared/desktop-policy.nix {
        contracts = registry.definitions.gnomeOnly.contracts;
        desktopDefaults = import ../../lib/features/desktop-defaults.nix {
          inherit (partial) selected;
        };
      })
      ../../contracts/system/services/session.nix
      ../../contracts/system/services/gnome.nix
      ../../contracts/system/services/network.nix
      ../../contracts/system/services/audio.nix
      ../../contracts/system/services/bluetooth.nix
      ../../contracts/system/services/power.nix
      ../../contracts/system/services/storage.nix
      {
        options.assertions = lib.mkOption {
          type = lib.types.listOf lib.types.raw;
          default = [ ];
        };
        config.features = partial.config;
      }
    ];
  };
  nativeBootstrap = import ../fixtures/platform.nix { port = registry.definitions.example; };
  views = import ../../lib/hosts/configuration-views.nix {
    output = registry.definitions.example.output;
    username = "test";
    configuration = {
      config.marker = "home";
      systemConfiguration.config.marker = "system";
    };
  };
  errorsFor =
    change:
    validate {
      inherit catalog;
      registry = registry // {
        definitions = registry.definitions // {
          example = change registry.definitions.example;
        };
      };
    };
in
assert validate { inherit registry catalog; } == [ ];
assert nativeBootstrap.hardwareConfig == null && nativeBootstrap.systemConfig == { };
assert views.home.marker == "home" && views.system.marker == "system";
assert partial.errors == [ ] && partial.selected.desktop == "gnome";
assert partialSystem.config.services.desktopManager.gnome.enable;
assert partialSystem.config.services.displayManager.gdm.enable;
assert partialSystem.config.services.displayManager.defaultSession == "gnome";
assert lib.all (a: a.assertion) partialSystem.config.assertions;
assert !(partialSystem.options ? programs);
assert unavailable.errors != [ ];
assert (partialShell "dms").errors == [ ] && (partialShell "dms").enabled.dms;
assert (partialShell "noctalia").errors != [ ];
assert !(builtins.elem "niriOnly" catalog.integrations.niri-noctalia.platforms);
assert builtins.elem "gnomeOnly" catalog.features.gnome.platforms;
assert !(builtins.elem "gnomeOnly" catalog.features.niri.platforms);
assert !(builtins.elem "gnomeOnly" catalog.features.dms.platforms);
assert selected.errors == [ ] && selected.selected.desktop == "niri";
assert builtins.elem "example" catalog.integrations.chrome-browser.platforms;
assert lib.any (error: lib.hasInfix "typo" error) (errorsFor (port: port // { typo = true; }));
assert lib.any (error: lib.hasInfix "builder" error) (
  errorsFor (port: port // { builder = "missing"; })
);
assert lib.any (error: lib.hasInfix "home implementation" error) (
  errorsFor (
    port:
    port
    // {
      features = builtins.removeAttrs port.features [ "gnome" ];
    }
  )
);
{
  nativeFixtureUsesDeploymentMetadata = true;
  desktopFamilyExtendsWithoutPlatformBranches = true;
  partialDesktopPortNeedsOnlyImplementedCapabilities = true;
  invalidPortMetadataRejected = true;
  missingImplementationRejected = true;
}
