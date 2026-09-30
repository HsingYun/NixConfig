{
  config,
  osConfig,
  lib,
  software,
  ...
}:
let
  system = osConfig.programs.noctalia;
  home = config.programs.noctalia;
  running = (system.enable && system.systemd.enable) || (home.enable && home.systemd.enable);
  command =
    if system.enable && system ? package then
      lib.getExe system.package
    else if home.package != null then
      lib.getExe home.package
    else
      software.noctalia.command "noctalia";
  msg =
    args:
    [
      command
      "msg"
    ]
    ++ args;
in
{
  config = lib.mkIf (running && config.wayland.windowManager.niri.enable) {
    wayland.windowManager.niri.settings.binds = lib.mapAttrs (_: lib.mkDefault) {
      "Mod+Alt+L".spawn = msg [
        "session"
        "lock"
      ];
      "Mod+Space".spawn = msg [
        "panel-toggle"
        "launcher"
      ];
      "Mod+S".spawn = msg [
        "panel-toggle"
        "control-center"
      ];
      "Mod+Comma".spawn = msg [ "settings-toggle" ];
      "XF86AudioRaiseVolume".spawn = msg [ "volume-up" ];
      "XF86AudioLowerVolume".spawn = msg [ "volume-down" ];
      "XF86AudioMute".spawn = msg [ "volume-mute" ];
      "XF86MonBrightnessUp".spawn = msg [ "brightness-up" ];
      "XF86MonBrightnessDown".spawn = msg [ "brightness-down" ];
    };
  };
}
