{ inputs, pkgs }:
let
  inherit (inputs.nixpkgs) lib;
  inherit (inputs.home-manager.lib) hm;
  home =
    modules:
    inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        {
          home = {
            username = "upstream-probe";
            homeDirectory =
              if pkgs.stdenv.hostPlatform.isDarwin then "/Users/upstream-probe" else "/home/upstream-probe";
            stateVersion = "26.05";
          };
        }
      ]
      ++ modules;
    };
  priorityWinner =
    definitions:
    (lib.evalModules {
      modules = [
        { options.value = lib.mkOption { type = lib.types.str; }; }
      ]
      ++ map (value: { config.value = value; }) definitions;
    }).config.value;
  application =
    modules:
    (lib.evalModules {
      modules = [
        {
          options.value = lib.mkOption {
            default = null;
            type = lib.types.nullOr (
              lib.types.submodule {
                options.command = lib.mkOption { type = lib.types.listOf lib.types.str; };
                options.desktopId = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                };
              }
            );
          };
        }
        {
          options.value = lib.mkOption {
            type = lib.types.nullOr (
              lib.types.submodule {
                config = {
                  command = lib.mkDefault [ "/default" ];
                  desktopId = lib.mkDefault "default.desktop";
                };
              }
            );
          };
          config.value = lib.mkDefault { };
        }
      ]
      ++ modules;
    }).config.value;
  probes = {
    # entryBetween takes before first and after second: first -> middle -> last.
    "hm.dag.entryBetween-order" =
      let
        sorted = hm.dag.topoSort {
          first = hm.dag.entryAnywhere null;
          middle = hm.dag.entryBetween [ "last" ] [ "first" ] null;
          last = hm.dag.entryAnywhere null;
        };
      in
      sorted ? result
      &&
        map (entry: entry.name) sorted.result == [
          "first"
          "middle"
          "last"
        ];

    # HM's helper output is accepted as a file source, regardless of its representation.
    "hm.config-lib.file-helper" =
      let
        config =
          (home [
            ({ config, ... }: {
              home.file.upstream-helper.source = config.lib.file.mkOutOfStoreSymlink "/upstream-probe";
            })
          ]).config;
      in
      lib.hasPrefix "/" (toString config.home.file.upstream-helper.source);

    # A config-only declaration supplies defaults through a nullable submodule type.
    "nixpkgs.submodule.declaration-merge" =
      application [ ] == {
        command = [ "/default" ];
        desktopId = "default.desktop";
      };

    # A field override preserves the other defaults contributed by the policy.
    "nixpkgs.submodule.field-override" =
      application [ { value.command = [ "/custom" ]; } ] == {
        command = [ "/custom" ];
        desktopId = "default.desktop";
      };

    # Null on an optional field clears its default without disabling the application.
    "nixpkgs.submodule.field-null" =
      application [ { value.desktopId = null; } ] == {
        command = [ "/default" ];
        desktopId = null;
      };

    # An outer null disables the entire application despite policy defaults.
    "nixpkgs.submodule.null-disable" = application [ { value = null; } ] == null;

    # Conflicting scalar fields still fail inside the nullable policy submodule.
    "nixpkgs.submodule.conflict-rejection" =
      !(builtins.tryEval
        (application [
          { value.desktopId = "first.desktop"; }
          { value.desktopId = "second.desktop"; }
        ]).desktopId
      ).success;

    # HM accepts autostart enable/entries and generates the corresponding XDG file.
    "hm.xdg.autostart" =
      let
        config =
          (home [
            {
              xdg.autostart = {
                enable = true;
                entries = [ "/upstream-probe.desktop" ];
              };
            }
          ]).config;
      in
      config.xdg.autostart.enable
      && config.xdg.autostart.entries == [ "/upstream-probe.desktop" ]
      && lib.hasPrefix "/" (toString config.xdg.configFile.autostart.source);

    # Ordinary host definitions override the framework's stronger defaults (900).
    "nixpkgs.priority.host-over-platform" =
      priorityWinner [
        (lib.mkOverride 900 "platform")
        "host"
      ] == "host";

    # Platform restrictions (900) override selected-provider defaults (925).
    "nixpkgs.priority.platform-over-provider" =
      priorityWinner [
        (lib.mkOverride 925 "provider")
        (lib.mkOverride 900 "platform")
      ] == "platform";

    # Selected-provider defaults (925) override profile defaults (950).
    "nixpkgs.priority.provider-over-profile" =
      priorityWinner [
        (lib.mkOverride 950 "profile")
        (lib.mkOverride 925 "provider")
      ] == "provider";

    # Profile defaults (950) override shared mkDefault definitions.
    "nixpkgs.priority.profile-over-default" =
      priorityWinner [
        (lib.mkDefault "default")
        (lib.mkOverride 950 "profile")
      ] == "profile";

    # mkForce remains stronger than an ordinary host definition.
    "nixpkgs.priority.force-over-host" =
      priorityWinner [
        "host"
        (lib.mkForce "forced")
      ] == "forced";
  };
in
builtins.mapAttrs (
  name: passed:
  builtins.addErrorContext "Upstream assumption '${name}' failed:" (
    if passed then true else throw "Upstream assumption '${name}' no longer holds."
  )
) probes
