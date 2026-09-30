{ config, lib, ... }: {
  imports = [ ../../../../contracts/system/services/audio.nix ];
  config = lib.mkMerge [
    (lib.mkIf config.security.rtkit.enable { native.requiredPackages = [ "rtkit" ]; })
    (lib.mkIf config.services.pipewire.enable {
      native.requiredPackages = [
        "pipewire"
        "wireplumber"
      ]
      ++ lib.optional config.services.pipewire.alsa.enable "pipewire-alsa"
      ++ lib.optional config.services.pipewire.pulse.enable "pipewire-pulse";
    })
  ];
}
