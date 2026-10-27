{ lib }:
let
  # Keep the consumer fixed point separate from provider selection. The real
  # consumer module owns validation, demand flags and conditional definitions.
  state = {
    options = {
      software = {
        consumers = lib.mkOption { type = lib.types.attrsOf lib.types.raw; };
        resolved = lib.mkOption {
          type = lib.types.attrsOf lib.types.raw;
          default = { };
        };
        runtimeArtifacts = lib.mkOption {
          type = lib.types.attrsOf lib.types.raw;
          default = { };
        };
      };
      assertions = lib.mkOption {
        type = lib.types.listOf lib.types.raw;
        default = [ ];
      };
    };
  };
  adapter =
    overrides:
    import ../../modules/software/consumer.nix (
      {
        id = "probe";
        scope = "home";
        software = "probe";
        packageOption = [
          "application"
          "package"
        ];
        enableOptions = [
          [
            "application"
            "enable"
          ]
        ];
      }
      // overrides
    );
  application =
    overrides: enabled:
    (lib.evalModules {
      modules = [
        state
        (lib.mkRenamedOptionModule [ "legacy" ] [ "application" ])
        (adapter overrides)
        ({ config, ... }: {
          options.application = {
            enable = lib.mkEnableOption "probe";
            package = lib.mkOption {
              type = lib.types.str;
              default = "upstream";
            };
          };
          config = {
            application.enable = enabled;
            software.resolved = lib.optionalAttrs config.software.consumers.probe.enabled {
              probe.package = "selected";
            };
          };
        })
      ];
    }).config;
  invalidDeclarations = [
    {
      packageOption = [
        "legacy"
        "package"
      ];
    }
    {
      enableOptions = [
        [
          "legacy"
          "enable"
        ]
      ];
    }
    {
      runtimePackageOption = [
        "legacy"
        "package"
      ];
    }
    {
      packageOption = [
        "missing"
        "package"
      ];
    }
    { packageOption = [ "application" ]; }
  ];
  theme =
    enabled: requested: selected: extra:
    (lib.evalModules {
      modules = [
        state
        (adapter {
          requestWhenEnabled = false;
          enableOptions = [ [ "enable" ] ];
          packageOption = [
            "theme"
            "package"
          ];
        })
        {
          options = {
            enable = lib.mkEnableOption "theme binding";
            theme = lib.mkOption {
              default = null;
              type = lib.types.nullOr (
                lib.types.submodule {
                  options = {
                    name = lib.mkOption { type = lib.types.str; };
                    package = lib.mkOption {
                      type = lib.types.nullOr lib.types.str;
                      default = null;
                    };
                  };
                }
              );
            };
          };
          config = {
            enable = enabled;
            software.resolved = lib.optionalAttrs requested { probe.package = selected; };
          };
        }
        extra
      ];
    }).config;
  activeTheme = theme true true "selected" { theme.name = "Theme"; };
  nativeTheme = theme true true null { theme.name = "Native"; };
  customTheme = theme true true "selected" {
    theme = {
      name = "Custom";
      package = "custom";
    };
  };
  probes = {
    canonicalBinding = (application { } true).application.package == "selected";
    disabledBinding = (application { } false).application.package == "upstream";
    # Invalid declarations must fail before enablement or resolution, even when disabled.
    invalidInterfacesRejected = lib.all (
      overrides:
      lib.all
        (
          enabled:
          !(builtins.tryEval (application overrides enabled).software.consumers.probe.enabled).success
        )
        [
          true
          false
        ]
    ) invalidDeclarations;
    # A false leaf mkIf would create this nullable parent and leave name undefined.
    inactiveParentStaysNull =
      lib.all (flags: (theme flags.enabled flags.requested "selected" { }).theme == null)
        [
          {
            enabled = false;
            requested = false;
          }
          {
            enabled = false;
            requested = true;
          }
          {
            enabled = true;
            requested = false;
          }
        ];
    inactiveExplicitParentPreserved =
      (theme false true "selected" {
        theme = {
          name = "Existing";
          package = "user";
        };
      }).theme == {
        name = "Existing";
        package = "user";
      };
    activeSubmoduleBinding =
      activeTheme.theme == {
        name = "Theme";
        package = "selected";
      }
      && lib.all (a: a.assertion) activeTheme.assertions;
    nullablePackageMetadata = activeTheme.software.consumers.probe.capabilities == [ ];
    requiredPackageMetadata =
      (application { } true).software.consumers.probe.capabilities == [ "store-package" ];
    nativeSubmoduleBinding =
      nativeTheme.theme == {
        name = "Native";
        package = null;
      }
      && lib.all (a: a.assertion) nativeTheme.assertions;
    upstreamOverrideStillMerges =
      customTheme.theme.package == "custom" && !(lib.all (a: a.assertion) customTheme.assertions);
  };
in
lib.mapAttrs (
  name: passed:
  assert lib.assertMsg passed "Consumer binding regression '${name}' failed.";
  true
) probes
