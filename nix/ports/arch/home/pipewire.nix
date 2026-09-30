{
  config,
  lib,
  osConfig,
  ...
}:
let
  units = {
    "pipewire.service" = [ "default.target" ];
    "pipewire.socket" = [ "sockets.target" ];
    "wireplumber.service" = [ "pipewire.service" ];
  }
  // lib.optionalAttrs osConfig.services.pipewire.pulse.enable {
    "pipewire-pulse.service" = [ "default.target" ];
    "pipewire-pulse.socket" = [ "sockets.target" ];
  };
  link = name: config.lib.file.mkOutOfStoreSymlink "/usr/lib/systemd/user/${name}";
in
{
  config = lib.mkIf (osConfig.services.pipewire.enable) {
    systemd.user.startServices = lib.mkDefault true;
    xdg.configFile =
      lib.concatMapAttrs (
        name: targets:
        {
          "systemd/user/${name}".source = link name;
        }
        // lib.listToAttrs (
          map (
            target: lib.nameValuePair "systemd/user/${target}.wants/${name}" { source = link name; }
          ) targets
        )
      ) units
      // {
        "systemd/user/pipewire-session-manager.service".source = link "wireplumber.service";
      };
  };
}
