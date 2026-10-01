{ enabled, dms }:
{
  config,
  lib,
  ...
}:

let
  ipc = target: action: [
    dms
    "ipc"
    "call"
    target
    action
  ];
in
{
  imports = [ ../shared/niri.nix ];

  config = lib.mkIf (enabled && config.wayland.windowManager.niri.enable) {
    # DMS declares the files it owns. The Niri adapter coordinates their
    # loading with feature defaults and the official HM configuration.
    desktop.niri.runtimeIncludes =
      lib.mapAttrsToList
        (name: defaultSections: {
          path = "${config.xdg.configHome}/niri/dms/${name}.kdl";
          inherit defaultSections;
        })
        {
          alttab = [ ];
          binds = [ ];
          colors = [ "layout" ];
          cursor = [ ];
          input = [ "input" ];
          layout = [
            "layout"
            "_children"
          ];
          windowrules = [ "_children" ];
          wpblur = [ ];
        }
      ++ [
        {
          path = "${config.xdg.configHome}/niri/dms/outputs.kdl";
          strategy = "first-wins";
        }
      ];
    wayland.windowManager.niri.settings = {
      layer-rule = {
        match._props.namespace = lib.mkDefault "^quickshell$";
        place-within-backdrop = lib.mkDefault true;
      };
      binds = lib.mapAttrs (_: lib.mkDefault) {
        "Mod+Space" = {
          _props.hotkey-overlay-title = "Application launcher";
          spawn = ipc "spotlight" "toggle";
        };
        "Mod+V".spawn = ipc "clipboard" "toggle";
        "Mod+M".spawn = ipc "processlist" "focusOrToggle";
        "Ctrl+Alt+Delete".spawn = ipc "processlist" "focusOrToggle";
        "Mod+N".spawn = ipc "notifications" "toggle";
        "Mod+Comma".spawn = ipc "settings" "toggle";
        "Mod+Escape".spawn = ipc "powermenu" "toggle";
        "Mod+Alt+L" = {
          _props.hotkey-overlay-title = "Lock screen";
          spawn = ipc "lock" "lock";
        };
        "XF86AudioRaiseVolume" = {
          _props.allow-when-locked = true;
          spawn = ipc "audio" "increment" ++ [ "5" ];
        };
        "XF86AudioLowerVolume" = {
          _props.allow-when-locked = true;
          spawn = ipc "audio" "decrement" ++ [ "5" ];
        };
        "XF86AudioMute" = {
          _props.allow-when-locked = true;
          spawn = ipc "audio" "mute";
        };
        "XF86AudioMicMute".spawn = ipc "audio" "micmute";
        "XF86AudioPlay".spawn = ipc "mpris" "playPause";
        "XF86AudioNext".spawn = ipc "mpris" "next";
        "XF86AudioPrev".spawn = ipc "mpris" "previous";
        "XF86MonBrightnessUp".spawn = ipc "brightness" "increment" ++ [ "5" ];
        "XF86MonBrightnessDown".spawn = ipc "brightness" "decrement" ++ [ "5" ];
      };
    };
  };
}
