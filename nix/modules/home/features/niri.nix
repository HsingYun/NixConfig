{
  lib,
  osConfig,
  pkgs,
  ...
}:

{
  imports = [ ../shared/desktop.nix ];

  home.packages = with pkgs; [
    ghostty
    nautilus
    wl-clipboard
  ];
  xdg.userDirs = {
    enable = lib.mkDefault true;
    createDirectories = lib.mkDefault true;
  };
  xdg.terminal-exec.enable = lib.mkDefault true;

  wayland.windowManager.niri = {
    enable = lib.mkDefault true;
    package = lib.mkDefault osConfig.programs.niri.package;
    # NixOS owns the session units and desktop portals.
    systemd.enable = false;
    portalPackage = null;
    checkConfig = lib.mkDefault true;

    settings = {
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

      binds = lib.mapAttrs (_: lib.mkDefault) {
        "Mod+Return" = {
          _props.hotkey-overlay-title = "Terminal";
          spawn = [ (lib.getExe pkgs.xdg-terminal-exec) ];
        };
        "Mod+E".spawn = [ (lib.getExe pkgs.nautilus) ];

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

      };
    };
  };
}
