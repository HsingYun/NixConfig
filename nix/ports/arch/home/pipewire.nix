{
  lib,
  osConfig,
  ...
}:
{
  config = lib.mkIf (osConfig.services.pipewire.enable) {
    native.systemd.user.units = {
      "pipewire.service".wantedBy = [ "default.target" ];
      "pipewire.socket".wantedBy = [ "sockets.target" ];
      "wireplumber.service" = {
        wantedBy = [ "pipewire.service" ];
        aliases = [ "pipewire-session-manager.service" ];
      };
    }
    // lib.optionalAttrs osConfig.services.pipewire.pulse.enable {
      "pipewire-pulse.service".wantedBy = [ "default.target" ];
      "pipewire-pulse.socket".wantedBy = [ "sockets.target" ];
    };
  };
}
