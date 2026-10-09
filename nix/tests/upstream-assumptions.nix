{ inputs, pkgs }:
let
  inherit (inputs.nixpkgs) lib;
  inherit (inputs.home-manager.lib) hm;
  # Ports consume config/options; only Niri forwards imports. Metadata does not
  # affect delegation, but unhandled module loading or typing directives do.
  portModule =
    forwardsImports: module:
    module ? config
    && module ? options
    && (
      if forwardsImports then builtins.isList (module.imports or null) else (module.imports or [ ]) == [ ]
    )
    && (module.disabledModules or [ ]) == [ ]
    && (module.freeformType or null) == null;
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
    # Recipe eligibility uses nixpkgs' evaluated policy, not a second metadata check.
    "nixpkgs.meta.available" = pkgs.hello.meta ? available && builtins.isBool pkgs.hello.meta.available;
    # The Arch GDM port reuses NixOS's AccountsService session utility.
    "nixos.gdm.session-utility" = lib.isDerivation (
      inputs.nixpkgs.legacyPackages.x86_64-linux.callPackage
        "${inputs.nixpkgs}/nixos/modules/services/x11/display-managers/account-service-util.nix"
        { }
    );
    # The Arch port delegates Niri configuration and replaces only native unit installation.
    "hm.niri.port-interface" =
      let
        module = import "${inputs.home-manager}/modules/services/window-managers/niri.nix" {
          inherit lib pkgs;
          config = { };
        };
      in
      portModule true module
      && module.options.wayland.windowManager.niri.package.type.check null
      && module.options.wayland.windowManager.niri.systemd.enable.type.check true;
    # Native mpv delegates script placement; upstream owns the unchanged schema and text generation.
    "hm.mpv.port-interface" =
      let
        h = home [ ];
        upstream = import "${inputs.home-manager}/modules/programs/mpv.nix" {
          inherit lib pkgs;
          inherit (h) config options;
        };
      in
      portModule false upstream
      && upstream.options.programs.mpv.finalPackage.readOnly
      && upstream.options.programs.mpv.package.type.check null
      && upstream.options.programs.mpv.scripts.type.check [ pkgs.mpvScripts.modernx ];
    # The native Vim port reuses these declarations and the unchanged Nix config.
    "hm.vim.port-interface" =
      let
        module = import "${inputs.home-manager}/modules/programs/vim.nix" {
          inherit lib pkgs;
          config = { };
        };
      in
      portModule false module
      && module.options.programs.vim.package.readOnly
      && module.options.programs.vim.packageConfigurable.type.check pkgs.vim
      && builtins.isList module.options.programs.vim.plugins.default;

    # The Arch keyring port gates only config; upstream owns the Nix service.
    "hm.gnome-keyring.port-interface" =
      let
        module = import "${inputs.home-manager}/modules/services/gnome-keyring.nix" {
          inherit lib pkgs;
          config = { };
        };
      in
      portModule false module
      && module.options.services.gnome-keyring.components.type.check [
        "pkcs11"
        "secrets"
      ];

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
# Keep the probe boundary narrow: additive metadata is harmless, while ignored
# imports, disabled modules or freeform typing could change the port's behavior.
assert portModule false {
  config = { };
  options = { };
  meta.maintainers = [ ];
  _file = "probe.nix";
};
assert
  !(portModule false {
    config = { };
    options = { };
    imports = [ { } ];
  });
assert portModule true {
  config = { };
  options = { };
  imports = [ { } ];
};
assert
  !(portModule false {
    config = { };
    options = { };
    disabledModules = [ "probe.nix" ];
  });
assert
  !(portModule false {
    config = { };
    options = { };
    freeformType = lib.types.attrs;
  });
builtins.mapAttrs (
  name: passed:
  builtins.addErrorContext "Upstream assumption '${name}' failed:" (
    if passed then true else throw "Upstream assumption '${name}' no longer holds."
  )
) probes
