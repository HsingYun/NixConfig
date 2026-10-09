{
  config,
  helpers,
  lib,
  ...
}:
let
  inherit (helpers) kdl;
in
{
  imports = [ ../shared/niri.nix ];
  config =
    lib.mkIf
      (
        config.features.desktop.niri.enable
        && config.wayland.windowManager.niri.enable
        && config.features.mpv.enable
        && config.programs.mpv.enable
      )
      {
        # Follow general and file-manager defaults, preserving rule precedence.
        desktop.niri.defaultSettings = kdl.children (
          lib.mkOrder 1600 [
            (kdl.node "window-rule" [ ] {
              match = kdl.props { app-id = "^mpv$"; };
              open-floating = true;
              default-column-width.fixed = 1280;
              default-window-height.fixed = 720;
            })
          ]
        );
      };
}
