{
  config,
  lib,
  osConfig,
  ...
}:

let
  dms = lib.getExe osConfig.programs.dms-shell.package;
  ipc = target: action: [
    dms
    "ipc"
    "call"
    target
    action
  ];
in
{
  config =
    lib.mkIf
      (
        osConfig.programs.niri.enable
        && osConfig.programs.dms-shell.enable
        && config.wayland.windowManager.niri.enable
      )
      {
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
