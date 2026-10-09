{ inputs, lib }:
let
  roles = import ../../lib/desktop/roles.nix;
  evaluate =
    modules:
    lib.evalModules {
      modules = [
        ../../modules/home/shared/applications.nix
        {
          options.assertions = lib.mkOption {
            type = lib.types.listOf lib.types.unspecified;
            default = [ ];
          };
          options.entries = lib.mkOption (import ../../lib/features/autostart.nix { inherit lib; });
        }
      ]
      ++ modules;
    };
  valid = evaluation: lib.all (check: check.assertion) evaluation.config.assertions;
  empty = evaluate [ ];
  selected = evaluate [
    {
      desktop.applications = lib.genAttrs roles (role: {
        command = [ "/example/${role}" ];
      });
      entries = lib.genAttrs roles (role: {
        application = role;
      });
    }
  ];
  # A policy may supply defaults for a subset without requiring every role to be selected.
  partial = evaluate [
    {
      options.desktop.applications.terminal = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.submodule {
            config.command = lib.mkDefault [ "/example/terminal" ];
          }
        );
      };
      config.desktop.applications.terminal = lib.mkDefault { };
    }
  ];
  # An extra option declaration must not bypass the registry through Nix's module merging.
  unregistered = evaluate [
    {
      options.desktop.applications.unregistered = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
    }
  ];
  invalidAutostart = evaluate [ { entries.probe.application = "unregistered"; } ];
  # The consumer must work with upstream HM and selected roles alone, without
  # importing this repository's feature policies or software coordinator.
  consumer =
    system: applications:
    (inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = inputs.nixpkgs.legacyPackages.${system};
      modules = [
        ../../modules/home/integrations/applications.nix
        {
          home = {
            username = "test";
            homeDirectory = if lib.hasSuffix "-darwin" system then "/Users/test" else "/home/test";
            stateVersion = "26.05";
          };
          desktop.applications = applications;
        }
      ];
    }).config;
  consumerIndependent =
    system:
    let
      applications = lib.genAttrs roles (role: {
        command = [ "/example/${role}" ];
        desktopId = "example-${role}.desktop";
      });
      active = consumer system applications;
      inactive = consumer system { };
      linux = lib.hasSuffix "-linux" system;
    in
    assert lib.all (cfg: !(cfg ? features) && !(cfg ? software)) [
      active
      inactive
    ];
    assert lib.all (cfg: lib.all (check: check.assertion) cfg.assertions) [
      active
      inactive
    ];
    assert active.home.sessionVariables.TERMINAL == "/example/terminal";
    assert !(inactive.home.sessionVariables ? TERMINAL);
    assert active.xdg.terminal-exec.enable == linux;
    assert active.xdg.mimeApps.enable == linux;
    assert !inactive.xdg.terminal-exec.enable && !inactive.xdg.mimeApps.enable;
    assert !linux || active.xdg.terminal-exec.settings.default == [ "example-terminal.desktop" ];
    assert
      !linux
      ||
        lib.all (mime: active.xdg.mimeApps.defaultApplications.${mime} == [ "example-browser.desktop" ])
          [
            "text/html"
            "application/xhtml+xml"
            "x-scheme-handler/http"
            "x-scheme-handler/https"
          ];
    assert
      !linux
      || active.xdg.mimeApps.defaultApplications."inode/directory" == [ "example-fileManager.desktop" ];
    true;
in
assert lib.all consumerIndependent [
  "x86_64-linux"
  "aarch64-darwin"
];
assert valid empty && valid selected && valid partial;
assert builtins.attrNames empty.config.desktop.applications == lib.sort builtins.lessThan roles;
assert lib.all (role: empty.config.desktop.applications.${role} == null) roles;
assert lib.all (
  role:
  selected.config.entries.${role}.application == role
  && selected.config.desktop.applications.${role}.command == [ "/example/${role}" ]
) roles;
assert partial.config.desktop.applications.terminal.command == [ "/example/terminal" ];
assert lib.all (role: partial.config.desktop.applications.${role} == null) (
  lib.remove "terminal" roles
);
assert !(valid unregistered);
assert lib.any (
  check: !check.assertion && lib.hasInfix "unregistered" check.message
) unregistered.config.assertions;
assert !(builtins.tryEval (builtins.deepSeq invalidAutostart.config.entries true)).success;
true
