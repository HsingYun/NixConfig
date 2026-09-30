{ lib }:
let
  base = import ../../lib/platforms;
  registry = base // {
    definitions = base.definitions // {
      example = base.definitions.arch;
    };
    all = base.all ++ [ "example" ];
    linux = base.linux ++ [ "example" ];
    desktops = base.desktops ++ [ "example" ];
  };
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
      features = builtins.removeAttrs port.features [ "niri" ];
    }
  )
);
{
  desktopFamilyExtendsWithoutPlatformBranches = true;
  invalidPortMetadataRejected = true;
  missingImplementationRejected = true;
}
