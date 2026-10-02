{
  config,
  lib,
  software,
  ...
}:
let
  ghosttyEnabled = config.features.ghostty.enable && config.programs.ghostty.enable;
  # Linux's Chrome feature installs through the software plan, independently
  # of Home Manager's optional Chrome configuration module.
  chromeEnabled =
    config.features.chrome.enable
    && software ? chrome
    && (software.chrome.provider != "nix" || software.chrome.runtimePackage != null);
  defaults = {
    input.touchpad = {
      tap = { };
      natural-scroll = { };
    };
    layout = {
      gaps = 12;
      background-color = "transparent";
      center-focused-column = "never";
      default-column-width.proportion = 0.5;
      preset-column-widths._children = [
        { proportion = 0.33333; }
        { proportion = 0.5; }
        { proportion = 0.66667; }
      ];
      focus-ring = {
        width = 2;
        active-color = "#89b4fa";
        inactive-color = "#45475a";
      };
    };
    _children = [
      {
        window-rule = {
          geometry-corner-radius = 12;
          clip-to-geometry = true;
        };
      }
    ]
    ++ lib.optional config.features.desktop.fileManager.enable {
      window-rule = {
        match._props.app-id = "^org\\.gnome\\.Nautilus$";
        open-floating = true;
      };
    }
    ++ lib.optional (config.features.mpv.enable && config.programs.mpv.enable) {
      window-rule = {
        match._props.app-id = "^mpv$";
        open-floating = true;
        default-column-width.fixed = 1280;
        default-window-height.fixed = 720;
      };
    };
  };
in
{
  imports = [
    ../shared/desktop.nix
    ../shared/niri.nix
    ../shared/terminal-exec.nix
  ];

  desktop.niri.defaultSettings = defaults;
  software.requirements.wl-clipboard = { };
  xdg = {
    userDirs = {
      enable = lib.mkDefault true;
      createDirectories = lib.mkDefault true;
    };
    terminal-exec.enable = lib.mkDefault true;
  };

  wayland.windowManager.niri = {
    enable = lib.mkDefault true;
    settings = lib.mkMerge [
      config.features.desktop.niri.settings
      {
        spawn-at-startup = lib.mkIf ghosttyEnabled (lib.mkDefault [ (software.ghostty.command "ghostty") ]);
        environment = lib.mkIf config.features.chinese.enable {
          GTK_IM_MODULE = null; # Do not inherit the GNOME session's GTK override.
          LANG = lib.mkDefault "zh_CN.UTF-8";
          XMODIFIERS = lib.mkDefault "@im=fcitx";
          ELECTRON_OZONE_PLATFORM_HINT = lib.mkDefault "auto";
          QT_QPA_PLATFORMTHEME = lib.mkDefault "gtk3";
          QT_QPA_PLATFORMTHEME_QT6 = lib.mkDefault "gtk3";
        };
        prefer-no-csd = { };
        hotkey-overlay.skip-at-startup = lib.mkDefault { };
        screenshot-path = lib.mkDefault "~/Pictures/Screenshots/%Y-%m-%d_%H-%M-%S.png";

        binds = lib.mapAttrs (_: lib.mkDefault) (
          {
            "Mod+Return" = {
              _props.hotkey-overlay-title = "Terminal";
              spawn = [ (software.xdg-terminal-exec.command "xdg-terminal-exec") ];
            };

            "Mod+Q".close-window = { };
            "Mod+D" = {
              _props.repeat = false;
              toggle-overview = { };
            };
            "Mod+Tab" = {
              _props.repeat = false;
              toggle-overview = { };
            };
            "Mod+O".toggle-overview = { };
            "Mod+Shift+Slash".show-hotkey-overlay = { };
            "Mod+Shift+E".quit = { };

            "Mod+Left".focus-column-left = { };
            "Mod+Right".focus-column-right = { };
            "Mod+Up".focus-window-up = { };
            "Mod+Down".focus-window-down = { };
            "Mod+H".focus-column-left = { };
            "Mod+L".focus-column-right = { };
            "Mod+K".focus-window-up = { };
            "Mod+J".focus-window-down = { };

            "Mod+Ctrl+Left".move-column-left = { };
            "Mod+Ctrl+Right".move-column-right = { };
            "Mod+Ctrl+Up".move-window-up = { };
            "Mod+Ctrl+Down".move-window-down = { };
            "Mod+Page_Up".focus-workspace-up = { };
            "Mod+Page_Down".focus-workspace-down = { };
            "Mod+Ctrl+Page_Up".move-column-to-workspace-up = { };
            "Mod+Ctrl+Page_Down".move-column-to-workspace-down = { };

            "Mod+F".maximize-column = { };
            "Mod+Shift+F".fullscreen-window = { };
            "Mod+C".center-column = { };
            "Mod+R".switch-preset-column-width = { };
            "Mod+Shift+Space".toggle-window-floating = { };
            "Mod+Minus".set-column-width = "-10%";
            "Mod+Equal".set-column-width = "+10%";

            "Print".screenshot = { };
            "Ctrl+Print".screenshot-screen = { };
            "Alt+Print".screenshot-window = { };

          }
          // lib.optionalAttrs config.features.desktop.fileManager.enable {
            "Mod+E".spawn = [ (software.nautilus.command "nautilus") ];
          }
          // lib.optionalAttrs chromeEnabled {
            "Mod+B".spawn = [ (software.chrome.command "google-chrome-stable") ];
          }
          // lib.optionalAttrs ghosttyEnabled {
            "Mod+T".spawn = [ (software.ghostty.command "ghostty") ];
          }
        );
      }
    ];
  };
}
