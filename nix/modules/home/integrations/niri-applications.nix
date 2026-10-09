{
  config,
  helpers,
  lib,
  software,
  ...
}:
let
  inherit (helpers) kdl;
  apps = config.desktop.applications;

in
{
  config = lib.mkIf config.wayland.windowManager.niri.enable {
    desktop.niri.defaultSettings = kdl.children (
      lib.mkAfter (
        lib.optional (apps.fileManager != null && apps.fileManager.appId != null) (
          kdl.node "window-rule" [ ] {
            match = kdl.props { app-id = apps.fileManager.appId; };
            open-floating = true;
          }
        )
      )
    );
    wayland.windowManager.niri.settings = {
      binds = lib.mapAttrs (_: lib.mkDefault) (
        lib.optionalAttrs config.xdg.terminal-exec.enable {
          "Mod+Return" = {
            _props.hotkey-overlay-title = "Terminal";
            spawn = [ (software.xdg-terminal-exec.command "xdg-terminal-exec") ];
          };
        }
        // lib.optionalAttrs (apps.terminal != null) { "Mod+T".spawn = apps.terminal.command; }
        // lib.optionalAttrs (apps.browser != null) { "Mod+B".spawn = apps.browser.command; }
        // lib.optionalAttrs (apps.fileManager != null) { "Mod+E".spawn = apps.fileManager.command; }
      );
    };
  };
}
