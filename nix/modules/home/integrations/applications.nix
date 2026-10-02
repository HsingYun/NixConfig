{
  config,
  lib,
  pkgs,
  ...
}:
let
  apps = config.desktop.applications;
  hasDesktop = app: app != null && app.desktopId != null;
in
{
  imports = [ ../shared/applications.nix ];
  home.sessionVariables = lib.mkIf (apps.terminal != null) {
    TERMINAL = lib.mkDefault (builtins.head apps.terminal.command);
  };
  xdg = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    terminal-exec = lib.mkIf (hasDesktop apps.terminal) {
      enable = lib.mkDefault true;
      settings.default = lib.mkDefault [ apps.terminal.desktopId ];
    };
    mimeApps = lib.mkIf (hasDesktop apps.browser || hasDesktop apps.fileManager) {
      enable = lib.mkDefault true;
      defaultApplications = lib.mkMerge [
        (lib.mkIf (hasDesktop apps.browser) (
          lib.genAttrs [
            "text/html"
            "application/xhtml+xml"
            "x-scheme-handler/http"
            "x-scheme-handler/https"
          ] (_: lib.mkDefault [ apps.browser.desktopId ])
        ))
        (lib.mkIf (hasDesktop apps.fileManager) {
          "inode/directory" = lib.mkDefault [ apps.fileManager.desktopId ];
        })
      ];
    };
  };
}
