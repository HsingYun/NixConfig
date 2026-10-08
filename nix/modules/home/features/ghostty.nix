{
  config,
  lib,
  pkgs,
  software,
  ...
}:

let
  inherit (pkgs.stdenv.hostPlatform) isDarwin isLinux;
in
{
  software = {
    requirements = {
      ghostty = { };
      maple-mono = { };
    };
  };
  programs.ghostty = {
    enable = lib.mkDefault true;

    systemd.enable = lib.mkDefault (
      builtins.elem "systemd-service" software.ghostty.providedCapabilities
    );
    enableZshIntegration = lib.mkDefault true;
    settings = lib.mkMerge [
      config.features.ghostty.settings
      (lib.mapAttrs (_: lib.mkDefault) (
        {
          font-family = "Maple Mono NF CN";
          font-size = 12;
          adjust-cell-height = 2;
          theme = "Catppuccin Mocha";
          background-opacity = 0.95;
          background-blur-radius = 30;
          window-padding-x = 10;
          window-padding-y = 8;
          window-theme = "auto";
          window-inherit-working-directory = true;
          confirm-close-surface = true;
          cursor-style = "bar";
          cursor-style-blink = true;
          cursor-opacity = 0.8;
          mouse-hide-while-typing = true;
          copy-on-select = "clipboard";
          quick-terminal-position = "top";
          quick-terminal-screen = "mouse";
          quick-terminal-autohide = true;
          quick-terminal-animation-duration = 0.15;
          clipboard-paste-protection = true;
          clipboard-paste-bracketed-safe = true;
          shell-integration = "detect";
          shell-integration-features = "ssh-terminfo,ssh-env";
          scrollback-limit = 25000000;
        }
        // lib.optionalAttrs isLinux {
          gtk-titlebar-style = "tabs";
          gtk-tabs-location = "top";
          gtk-wide-tabs = false;
          gtk-toolbar-style = "raised-border";
        }
        // lib.optionalAttrs isDarwin {
          macos-titlebar-style = "transparent";
          window-save-state = "always";
        }
      ))
    ];
  };
}
