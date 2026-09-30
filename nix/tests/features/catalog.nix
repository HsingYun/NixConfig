{ lib }:

let
  catalog = import ../../lib/features/catalog.nix { inherit lib; };
  validate = import ../../lib/features/validate.nix { inherit lib; };
  feature =
    patch:
    catalog
    // {
      features = catalog.features // {
        gpg = catalog.features.gpg // patch;
      };
    };
  choice =
    patch:
    catalog
    // {
      choices = catalog.choices // {
        desktop = catalog.choices.desktop // patch;
      };
    };
  cases = [
    {
      name = "unknown-contract";
      value = feature { contracts = [ "home.missing" ]; };
      message = "unknown contract 'home.missing'";
    }
    {
      name = "missing-port-contract";
      value = feature { contracts = [ "system.desktop" ]; };
      message = "requires contract 'system.desktop'";
    }
    {
      name = "missing-port-implementation";
      value = feature { portScopes = [ "home" ]; };
      message = "requires a home implementation";
    }
    {
      name = "platform-module-type";
      value = feature { homeModulesByPlatform.arch = "wrong"; };
      message = "homeModulesByPlatform is unknown";
    }
    {
      name = "platform-module-range";
      value = feature {
        platforms = [ "nixos" ];
        homeModulesByPlatform.arch = [ { } ];
      };
      message = "homeModulesByPlatform is unknown";
    }
    {
      name = "platform-activation-range";
      value = feature {
        platforms = [ "nixos" ];
        activationByPlatform.arch = {
          scope = "home";
          option = [ "enable" ];
        };
      };
      message = "activationByPlatform keys must be a subset";
    }
    {
      name = "empty-feature-path";
      value = feature { path = [ ]; };
      message = "features.gpg.path";
    }
    {
      name = "duplicate-feature-path";
      value = feature { path = [ "chrome" ]; };
      message = "input paths must be unique";
    }
    {
      name = "feature-path-leaf-conflict";
      value = feature {
        path = [
          "chrome"
          "enable"
        ];
      };
      message = "cannot also be a group";
    }
    {
      name = "unknown-default-source";
      value = feature { defaultFrom = [ "missing" ]; };
      message = "defaultFrom references unknown feature";
    }
    {
      name = "default-cycle";
      value = feature { defaultFrom = [ "gpg" ]; };
      message = "dependency cycle";
    }
    {
      name = "reserved-enable-option";
      value = feature {
        options.enable = {
          default = true;
          type = lib.types.bool;
          description = "a boolean";
        };
      };
      message = "features.gpg.options";
    }
    {
      name = "invalid-option-default";
      value = feature {
        options.example = {
          default = "bad";
          type = lib.types.bool;
          description = "a boolean";
        };
      };
      message = "features.gpg.options";
    }
    {
      name = "integration-missing-owner";
      value = catalog // {
        integrations.bad.platforms = [ "nixos" ];
      };
      message = "integrations.bad.owners is required";
    }
    {
      name = "integration-empty-owners";
      value = catalog // {
        integrations.bad = {
          platforms = [ "nixos" ];
          owners = [ ];
        };
      };
      message = "integrations.bad.owners has an invalid value";
    }
    {
      name = "integration-duplicate-owners";
      value = catalog // {
        integrations.bad = {
          platforms = [ "nixos" ];
          owners = [
            "gpg"
            "gpg"
          ];
        };
      };
      message = "integrations.bad.owners has an invalid value";
    }
    {
      name = "integration-platform";
      value = catalog // {
        integrations.bad = {
          platforms = [ "darwin" ];
          owners = [ "niri" ];
        };
      };
      message = "integrations.bad.owners.niri is unavailable";
    }
    {
      name = "root-type";
      value = [ ];
      message = "catalog must be an attribute set";
    }
    {
      name = "missing-section";
      value = builtins.removeAttrs catalog [ "choices" ];
      message = "catalog.choices is required";
    }
    {
      name = "unknown-section";
      value = catalog // {
        typo = { };
      };
      message = "catalog.typo is unknown";
    }
    {
      name = "entry-type";
      value = catalog // {
        features.gpg = true;
      };
      message = "features.gpg must be an attribute set";
    }
    {
      name = "field-typo";
      value = feature { defaut = true; };
      message = "features.gpg.defaut is unknown";
    }
    {
      name = "default-platform-range";
      value = feature {
        platforms = [ "nixos" ];
        defaultPlatforms = [ "darwin" ];
      };
      message = "defaultPlatforms must be a subset";
    }
    {
      name = "default-type";
      value = feature { default = "true"; };
      message = "features.gpg.default";
    }
    {
      name = "unknown-platform";
      value = feature { platforms = [ "macos" ]; };
      message = "features.gpg.platforms";
    }
    {
      name = "duplicate-platform";
      value = feature {
        platforms = [
          "arch"
          "arch"
        ];
      };
      message = "features.gpg.platforms";
    }
    {
      name = "empty-platforms";
      value = feature { platforms = [ ]; };
      message = "features.gpg.platforms";
    }
    {
      name = "system-platform-range";
      value = feature {
        platforms = [ "arch" ];
        systemPlatforms = [ "nixos" ];
      };
      message = "systemPlatforms must be a subset";
    }
    {
      name = "module-type";
      value = feature { homeModules = [ 42 ]; };
      message = "features.gpg.homeModules";
    }
    {
      name = "missing-module";
      value = feature { homeModules = [ ./missing-module.nix ]; };
      message = "features.gpg.homeModules";
    }
    {
      name = "requires-type";
      value = feature { requires = "git"; };
      message = "features.gpg.requires";
    }
    {
      name = "unknown-dependency";
      value = feature { requires = [ "typo" ]; };
      message = "requires references unknown feature 'typo'";
    }
    {
      name = "unknown-conflict";
      value = feature { conflicts = [ "typo" ]; };
      message = "conflicts references unknown feature 'typo'";
    }
    {
      name = "self-conflict";
      value = feature { conflicts = [ "gpg" ]; };
      message = "cannot conflict with itself";
    }
    {
      name = "cycle";
      value = feature { requires = [ "gpgSshSupport" ]; };
      message = "dependency cycle";
    }
    {
      name = "missing-activation";
      value = catalog // {
        features = catalog.features // {
          gpg = builtins.removeAttrs catalog.features.gpg [ "activation" ];
        };
      };
      message = "features.gpg.activation is required";
    }
    {
      name = "activation-scope";
      value = feature {
        activation = {
          scope = "host";
          option = [ "enable" ];
        };
      };
      message = "features.gpg.activation";
    }
    {
      name = "activation-path";
      value = feature {
        activation = {
          scope = "home";
          option = [ ];
        };
      };
      message = "features.gpg.activation";
    }
    {
      name = "activation-field";
      value = feature {
        activation = catalog.features.gpg.activation // {
          typo = true;
        };
      };
      message = "features.gpg.activation";
    }
    {
      name = "dependency-platform";
      value = feature {
        platforms = [ "nixos" ];
      };
      message = "unavailable on some source platforms";
    }
    {
      name = "unknown-provider";
      value = choice { providers.gnome = "typo"; };
      message = "providers.gnome references unknown feature";
    }
    {
      name = "empty-provider-list";
      value = choice { providers.gnome = [ ]; };
      message = "choices.desktop.providers";
    }
    {
      name = "unknown-provider-in-list";
      value = choice {
        providers.gnome = [
          "gnome"
          "typo"
        ];
      };
      message = "providers.gnome references unknown feature";
    }
    {
      name = "provider-type";
      value = choice { providers = [ "gnome" ]; };
      message = "choices.desktop.providers";
    }
    {
      name = "invalid-empty-choice";
      value = choice { empty = "typo"; };
      message = "empty must be null or an alternative";
    }
    {
      name = "incomplete-priority";
      value = choice { priority = [ "gnome" ]; };
      message = "priority must list every provider exactly once";
    }
    {
      name = "duplicate-priority";
      value = choice {
        priority = [
          "niri"
          "niri"
          "gnome"
        ];
      };
      message = "priority has an invalid value";
    }
    {
      name = "unknown-priority";
      value = choice {
        priority = [
          "niri"
          "typo"
        ];
      };
      message = "priority must list every provider exactly once";
    }
    {
      name = "overlapping-choice";
      value = choice { alternatives = [ "gnome" ]; };
      message = "alternatives must not overlap";
    }
    {
      name = "integration-reference";
      value = catalog // {
        integrations.bad = {
          platforms = [ "nixos" ];
          owners = [ "typo" ];
        };
      };
      message = "integrations.bad.owners references unknown feature";
    }
    {
      name = "integration-field";
      value = catalog // {
        integrations.bad = {
          platforms = [ "nixos" ];
          owners = [ "gpg" ];
          typo = true;
        };
      };
      message = "integrations.bad.typo is unknown";
    }
  ];
  verify =
    case:
    assert lib.assertMsg (lib.any (lib.hasInfix case.message) (
      validate case.value
    )) "Catalog diagnostic failed: ${case.name}";
    assert
      !(builtins.tryEval (
        import ../../lib/features/resolve.nix
          {
            inherit lib;
            catalog = case.value;
          }
          {
            name = "invalid-catalog";
            platform = "nixos";
          }
      )).success;
    case.name;
  activationCheck =
    home:
    let
      checks = import ../../lib/features/assertions.nix {
        inherit lib catalog;
        enabled = lib.genAttrs (builtins.attrNames catalog.features) (key: key == "gpgSshSupport");
      };
    in
    (checks.homeModule { config = home; }).assertions;
  validHome.services.gpg-agent = {
    enable = true;
    enableSshSupport = true;
  };
  invalidHomes = [
    { services.gpg-agent.enableSshSupport = false; }
    {
      services.gpg-agent = {
        enable = "true";
        enableSshSupport = false;
      };
    }
    {
      services.gpg-agent = {
        enable = true;
        enableSshSupport = "true";
      };
    }
  ];
in
assert validate catalog == [ ];
assert lib.all (a: a.assertion) (activationCheck validHome);
assert lib.all (
  home: !(builtins.tryEval (builtins.deepSeq (activationCheck home) true)).success
) invalidHomes;
{
  rejectedMetadata = map verify cases;
  rejectedActivationOptions = builtins.length invalidHomes;
}
