{ config, lib, ... }: {
  imports = [ ../../../../contracts/system/services/avahi.nix ];
  config = lib.mkMerge [
    (lib.mkIf config.services.avahi.enable {
      native.requiredPackages = [ "avahi" ];
      native.systemd.units = [
        "avahi-daemon.service"
        "avahi-daemon.socket"
      ];
    })
    {
      assertions = [
        {
          assertion = !config.services.avahi.nssmdns4;
          message = "Arch port: services.avahi.nssmdns4 is not implemented; configure NSS on the host or disable this option.";
        }
      ];
    }
  ];
}
