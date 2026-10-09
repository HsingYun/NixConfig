{
  config,
  helpers,
  options,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.desktop.niri;
  inherit (helpers) kdl;
  toKDL = kdl.render { inherit lib; };
  layer = helpers.configLayers { inherit lib; };
  runtimeSections = lib.genAttrs (builtins.attrNames orders) (
    strategy:
    lib.unique (
      lib.concatMap (fragment: fragment.defaultSections) (
        lib.filter (fragment: fragment.strategy == strategy) cfg.runtimeIncludes
      )
    )
  );
  runtimeDefaults = lib.mapAttrs (
    _: sections: lib.filterAttrs (name: _: builtins.elem name sections) cfg.defaultSettings
  ) runtimeSections;
  managedDefaults = builtins.removeAttrs cfg.defaultSettings (
    lib.concatLists (builtins.attrValues runtimeSections)
  );
  # HM emits enableDefaultConfig at 501 and settings at 999. Keep application
  # defaults before our fallback, then runtime fragments, then declarations.
  # The parser regression checks exercise both upstream configuration modes.
  orders = {
    last-wins = [
      502
      750
      999
    ];
    first-wins = [
      999
      1500
      1600
    ];
  };
  ordered =
    strategy: role:
    layer {
      inherit strategy;
      layer = role;
      order = orders.${strategy};
    };
  declarativeDefaults = lib.mapAttrsRecursiveCond (attrs: attrs != { }) (_: lib.mkDefault) (
    builtins.removeAttrs managedDefaults [ "_children" ]
  );
in
{
  imports = [ ../../shared/helpers.nix ];

  options.desktop.niri = {
    defaultSettings = lib.mkOption {
      type = options.wayland.windowManager.niri.settings.type;
      default = { };
      internal = true;
      description = "Feature defaults, merged by HM unless their section is assigned to a runtime configuration layer.";
    };
    runtimeIncludes = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            path = lib.mkOption { type = lib.types.str; };
            defaultSections = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Top-level default sections delegated to this fragment; _children denotes the ordered default rules.";
            };
            strategy = lib.mkOption {
              type = lib.types.enum [
                "last-wins"
                "first-wins"
              ];
              default = "last-wins";
            };
          };
        }
      );
      default = [ ];
      internal = true;
      description = "Application-owned Niri fragments and their parser merge semantics.";
    };
  };

  config = lib.mkIf config.wayland.windowManager.niri.enable {
    assertions = [
      {
        assertion = lib.intersectLists runtimeSections.first-wins runtimeSections.last-wins == [ ];
        message = "Niri: a default section cannot use both first-wins and last-wins runtime semantics.";
      }
    ];
    wayland.windowManager.niri = {
      # Keep ordinary Nix merging, including leaf overrides and mkForce, when
      # no runtime producer owns the section. Unrelated fragments must not
      # change its merge semantics. Repeated nodes use
      # standard list ordering so host rules follow the feature's rules.
      settings = lib.mkMerge [
        declarativeDefaults
        (lib.mkIf (managedDefaults ? _children) {
          _children = lib.mkBefore managedDefaults._children;
        })
      ];
      extraConfig = lib.mkMerge (
        lib.mapAttrsToList (
          strategy: settings:
          ordered strategy "defaults" (toKDL {
            include = toString (pkgs.writeText "niri-${strategy}-defaults.kdl" (toKDL settings));
          })
        ) (lib.filterAttrs (_: settings: settings != { }) runtimeDefaults)
        ++ map (
          fragment:
          ordered fragment.strategy "runtime" (
            toKDL (kdl.node "include" [ fragment.path ] (kdl.props { optional = true; }))
          )
        ) cfg.runtimeIncludes
      );
    };
  };
}
