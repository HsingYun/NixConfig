{
  config,
  lib,
  software,
  ...
}:
{
  imports = [
    ../shared/desktop.nix
    ../shared/terminal-exec.nix
  ];

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
    # The host OS owns session units and desktop portals.
    systemd.enable = false;
    portalPackage = null;

    settings = lib.mkMerge [
      config.features.desktop.niri.settings
      {
        environment = lib.mkIf config.features.chinese.enable {
          GTK_IM_MODULE = null; # Do not inherit the GNOME session's GTK override.
          LANG = lib.mkDefault "zh_CN.UTF-8";
          XMODIFIERS = lib.mkDefault "@im=fcitx";
          ELECTRON_OZONE_PLATFORM_HINT = lib.mkDefault "auto";
          QT_QPA_PLATFORMTHEME = lib.mkDefault "gtk3";
          QT_QPA_PLATFORMTHEME_QT6 = lib.mkDefault "gtk3";
        };
        input = {
          keyboard.xkb.layout = lib.mkDefault "us";
          touchpad = {
            tap = { };
            natural-scroll = { };
          };
        };

        layout = {
          gaps = lib.mkDefault 12;
          background-color = lib.mkDefault "transparent";
          center-focused-column = lib.mkDefault "never";
          default-column-width.proportion = lib.mkDefault 0.5;
          preset-column-widths._children = lib.mkDefault [
            { proportion = 0.33333; }
            { proportion = 0.5; }
            { proportion = 0.66667; }
          ];
          focus-ring = {
            width = lib.mkDefault 2;
            active-color = lib.mkDefault "#89b4fa";
            inactive-color = lib.mkDefault "#45475a";
          };
        };

        prefer-no-csd = { };
        screenshot-path = lib.mkDefault "~/Pictures/Screenshots/%Y-%m-%d_%H-%M-%S.png";

        window-rule = {
          geometry-corner-radius = lib.mkDefault 12;
          clip-to-geometry = lib.mkDefault true;
        };

        binds = lib.mapAttrs (_: lib.mkDefault) (
          {
            "Mod+Return" = {
              _props.hotkey-overlay-title = "Terminal";
              spawn = [ (software.xdg-terminal-exec.command "xdg-terminal-exec") ];
            };

            "Mod+Q".close-window = { };
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
        );
      }
    ];
  };
}
