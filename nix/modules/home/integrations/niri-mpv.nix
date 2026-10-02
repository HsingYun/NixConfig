{
  config,
  lib,
  ...
}:
{
  config =
    lib.mkIf
      (
        config.wayland.windowManager.niri.enable && config.features.mpv.enable && config.programs.mpv.enable
      )
      {
        # Follow general and file-manager defaults, preserving rule precedence.
        desktop.niri.defaultSettings._children = lib.mkOrder 1600 [
          {
            window-rule = {
              match._props.app-id = "^mpv$";
              open-floating = true;
              default-column-width.fixed = 1280;
              default-window-height.fixed = 720;
            };
          }
        ];
      };
}
