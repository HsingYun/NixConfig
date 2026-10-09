{ inputs, pkgs }:
let
  lib = pkgs.lib.extend (_: _: { inherit (inputs.home-manager.lib) hm; });
  inherit (import ../../lib/helpers.nix) kdl;
  render = kdl.render { inherit lib; };
  supplied =
    (lib.evalModules {
      modules = [
        ../../modules/shared/helpers.nix
        ({ helpers, lib, ... }: {
          options.value = lib.mkOption { type = lib.types.attrs; };
          config.value = helpers.kdl.node "output" [ "DP-2" ] { scale = 2; };
        })
      ];
    }).config.value;
  original = {
    _children = [
      {
        output = {
          _args = [ "Display \"A\"" ];
          scale = 1.5;
          position._props = {
            x = -1280;
            y = 0;
          };
        };
      }
      {
        output = {
          _args = [ "DP-2" ];
          scale = 2;
        };
      }
      {
        window-rule = {
          match._props.app-id = "^org\\.example$";
          open-floating = true;
        };
      }
    ];
  };
  constructed = kdl.children [
    (kdl.node "output" [ "Display \"A\"" ] {
      scale = 1.5;
      position = kdl.props {
        x = -1280;
        y = 0;
      };
    })
    (kdl.node "output" [ "DP-2" ] { scale = 2; })
    (kdl.node "window-rule" [ ] {
      match = kdl.props { app-id = "^org\\.example$"; };
      open-floating = true;
    })
  ];
  # Exercise HM's actual settings type, including list ordering and overrides.
  settings =
    modules:
    (inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        {
          home = {
            username = "test";
            homeDirectory = if pkgs.stdenv.hostPlatform.isDarwin then "/Users/test" else "/home/test";
            stateVersion = "26.05";
          };
        }
      ]
      ++ map (value: { wayland.windowManager.niri.settings = value; }) modules;
    }).config.wayland.windowManager.niri.settings;
  defaults = {
    layout.gaps = lib.mkDefault 12;
  }
  // kdl.children (lib.mkBefore [ (kdl.node "window-rule" [ ] { open-floating = false; }) ]);
  explicit = {
    layout.gaps = 20;
  }
  // constructed;
  combined = settings [
    explicit
    defaults
  ];
  forced = settings [
    explicit
    defaults
    (kdl.children (lib.mkForce [ ]))
  ];
in
assert render constructed == render original;
assert
  supplied == {
    output = {
      _args = [ "DP-2" ];
      scale = 2;
    };
  };
assert combined.layout.gaps == 20;
assert combined._children == [ { window-rule.open-floating = false; } ] ++ original._children;
assert forced._children == [ ] && forced.layout.gaps == 20;
{
  serialization = true;
  ordering = true;
  overrides = true;
  moduleArgument = true;
}
